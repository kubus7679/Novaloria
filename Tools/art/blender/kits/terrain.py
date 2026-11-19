"""Seamless terrain tiles: periodic procedural ground plus wrapped surface detail."""

from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Matrix

from . import common
from .common import HALF, TILE

# Colour stops (dark → light) for the large-scale field, a patch colour and surface detail.
GROUNDS: dict[str, dict] = {
    "plains": {
        "stops": [
            (0.0, (0.25, 0.36, 0.10)),
            (0.45, (0.38, 0.47, 0.14)),
            (0.75, (0.52, 0.54, 0.21)),
            (1.0, (0.60, 0.57, 0.27)),
        ],
        "patch": (0.56, 0.47, 0.27),
        "patch_at": 0.66,
        "detail": 0.32,
        "bump": 0.35,
    },
    "grassland": {
        "stops": [(0.0, (0.12, 0.30, 0.07)), (0.5, (0.20, 0.42, 0.11)), (1.0, (0.33, 0.52, 0.17))],
        "patch": (0.38, 0.50, 0.20),
        "patch_at": 0.62,
        "detail": 0.28,
        "bump": 0.3,
    },
    "prairie": {
        "stops": [(0.0, (0.42, 0.42, 0.13)), (0.5, (0.60, 0.55, 0.22)), (1.0, (0.72, 0.64, 0.31))],
        "patch": (0.40, 0.45, 0.16),
        "patch_at": 0.64,
        "detail": 0.3,
        "bump": 0.45,
    },
    "desert": {
        "stops": [(0.0, (0.66, 0.50, 0.30)), (0.5, (0.80, 0.66, 0.43)), (1.0, (0.88, 0.77, 0.55))],
        "patch": (0.60, 0.42, 0.26),
        "patch_at": 0.7,
        "detail": 0.18,
        "bump": 0.5,
        "ripples": 0.6,
    },
    "tundra": {
        "stops": [(0.0, (0.30, 0.33, 0.24)), (0.5, (0.42, 0.45, 0.33)), (1.0, (0.55, 0.55, 0.42))],
        "patch": (0.88, 0.91, 0.95),
        "patch_at": 0.7,
        "detail": 0.3,
        "bump": 0.5,
    },
    "marsh": {
        "stops": [(0.0, (0.16, 0.27, 0.10)), (0.5, (0.25, 0.37, 0.14)), (1.0, (0.36, 0.44, 0.19))],
        "patch": (0.07, 0.13, 0.12),
        "patch_at": 0.6,
        "detail": 0.28,
        "bump": 0.3,
        "wet": True,
    },
    "arctic": {
        "stops": [(0.0, (0.70, 0.78, 0.88)), (0.5, (0.86, 0.90, 0.96)), (1.0, (0.97, 0.98, 1.0))],
        "patch": (0.62, 0.74, 0.86),
        "patch_at": 0.72,
        "detail": 0.12,
        "bump": 0.6,
        "ripples": 0.45,
        "roughness": 0.55,
    },
}
GROUNDS["savannah"] = dict(GROUNDS["prairie"])
GROUNDS["swamp"] = dict(GROUNDS["marsh"])

# (kind, count, size range, colours)
SCATTER: dict[str, list[tuple[str, int, tuple[float, float], list[tuple[float, float, float]]]]] = {
    "plains": [
        ("bush", 10, (0.035, 0.06), [(0.11, 0.24, 0.06), (0.16, 0.30, 0.07)]),
        ("tuft", 70, (0.03, 0.05), [(0.42, 0.50, 0.15), (0.55, 0.55, 0.22)]),
        ("flower", 34, (0.010, 0.014), [(0.92, 0.80, 0.20), (0.95, 0.94, 0.88)]),
        ("rock", 4, (0.02, 0.035), [(0.50, 0.47, 0.42)]),
    ],
    "grassland": [
        ("bush", 14, (0.04, 0.065), [(0.06, 0.20, 0.05), (0.10, 0.27, 0.06)]),
        ("tuft", 80, (0.03, 0.055), [(0.18, 0.40, 0.09), (0.28, 0.48, 0.14)]),
        ("flower", 20, (0.010, 0.013), [(0.95, 0.95, 0.92), (0.62, 0.45, 0.80)]),
    ],
    "prairie": [
        ("tuft", 130, (0.045, 0.075), [(0.66, 0.58, 0.24), (0.54, 0.52, 0.18), (0.74, 0.64, 0.30)]),
        ("bush", 4, (0.035, 0.05), [(0.22, 0.30, 0.09)]),
        ("flower", 30, (0.011, 0.015), [(0.95, 0.62, 0.15), (0.92, 0.80, 0.18)]),
    ],
    "desert": [
        ("rock", 16, (0.02, 0.05), [(0.62, 0.50, 0.38), (0.52, 0.40, 0.30)]),
        ("bush", 6, (0.025, 0.04), [(0.38, 0.38, 0.20), (0.45, 0.40, 0.24)]),
        ("tuft", 14, (0.03, 0.045), [(0.66, 0.58, 0.36)]),
    ],
    "tundra": [
        ("rock", 20, (0.02, 0.05), [(0.48, 0.48, 0.46), (0.36, 0.36, 0.35)]),
        ("tuft", 30, (0.025, 0.04), [(0.50, 0.50, 0.30), (0.40, 0.44, 0.26)]),
        ("bush", 8, (0.025, 0.04), [(0.20, 0.25, 0.14)]),
    ],
    "marsh": [
        ("reed", 46, (0.06, 0.1), [(0.40, 0.42, 0.18), (0.30, 0.36, 0.14)]),
        ("tuft", 36, (0.03, 0.05), [(0.22, 0.36, 0.12)]),
        ("bush", 6, (0.035, 0.05), [(0.10, 0.22, 0.07)]),
    ],
    "arctic": [
        ("ice", 7, (0.04, 0.08), [(0.80, 0.90, 0.98)]),
        ("rock", 4, (0.02, 0.04), [(0.30, 0.31, 0.34)]),
    ],
}
SCATTER["savannah"] = SCATTER["prairie"]
SCATTER["swamp"] = SCATTER["marsh"]


def _angles(tree):
    position = tree.nodes.new("ShaderNodeNewGeometry").outputs["Position"]
    split = tree.nodes.new("ShaderNodeSeparateXYZ")
    tree.links.new(position, split.inputs[0])
    factor = 2.0 * math.pi / TILE
    return common.math_node(tree, "MULTIPLY", split.outputs["X"], factor), common.math_node(
        tree, "MULTIPLY", split.outputs["Y"], factor
    )


def _torus_noise(tree, a, b, scale, detail=4.0, roughness=0.55, offset=0.0, stretch=1.0):
    """Noise sampled on a torus in 4D, so it repeats exactly once per tile in both directions.

    Raw noise clusters around 0.5, so the result is stretched to use the full 0..1 range.
    """
    combine = tree.nodes.new("ShaderNodeCombineXYZ")
    tree.links.new(common.math_node(tree, "COSINE", a), combine.inputs["X"])
    tree.links.new(common.math_node(tree, "SINE", a), combine.inputs["Y"])
    tree.links.new(
        common.math_node(tree, "MULTIPLY", common.math_node(tree, "COSINE", b), stretch), combine.inputs["Z"]
    )
    w = common.math_node(tree, "MULTIPLY_ADD", common.math_node(tree, "SINE", b), stretch, offset)
    field = common.noise_texture(tree, combine.outputs["Vector"], scale, detail, roughness, w)
    return common.map_range(tree, field, 0.32, 0.68, 0.0, 1.0)


def _crests(tree, a, b, ka: int, kb: int, warp, sharpness: float = 4.0):
    """Periodic wave crests: integer wave numbers keep the pattern seamless across tiles."""
    phase = common.math_node(
        tree,
        "MULTIPLY_ADD",
        a,
        float(ka),
        common.math_node(tree, "MULTIPLY_ADD", b, float(kb), common.math_node(tree, "MULTIPLY", warp, 5.0)),
    )
    trough = common.math_node(
        tree, "SUBTRACT", 1.0, common.math_node(tree, "ABSOLUTE", common.math_node(tree, "SINE", phase))
    )
    return common.math_node(tree, "POWER", trough, sharpness)


def _ground_material(kind: str):
    config = GROUNDS[kind]
    material, tree, bsdf, _ = common.new_material(f"Ground-{kind}")
    a, b = _angles(tree)
    large = _torus_noise(tree, a, b, 0.45, 3.0, 0.5, 1.7)
    medium = _torus_noise(tree, a, b, 1.25, 4.0, 0.55, 5.3)
    fine = _torus_noise(tree, a, b, 4.0, 3.0, 0.6, 9.1)
    grain = _torus_noise(tree, a, b, 9.0, 2.0, 0.5, 13.7)
    color = common.ramp(tree, large, config["stops"])
    at = config["patch_at"]
    mask = common.ramp(tree, medium, [(at, (0.0, 0.0, 0.0)), (at + 0.07, (1.0, 1.0, 1.0))])
    color = common.mix_color(tree, common.math_node(tree, "MULTIPLY", mask, 0.65), color, config["patch"])
    warm = common.ramp(tree, medium, [
        (0.15, (0.60, 0.57, 0.43)), (0.5, (0.85, 0.83, 0.67)), (0.85, (1.0, 0.94, 0.78)),
    ])
    color = common.mix_color(tree, 0.22, color, warm, blend="MULTIPLY")
    hsv = tree.nodes.new("ShaderNodeHueSaturation")
    tree.links.new(color, hsv.inputs["Color"])
    detail = config["detail"]
    shade = common.math_node(
        tree,
        "MULTIPLY",
        common.math_node(tree, "MULTIPLY_ADD", fine, detail * 2.0, 1.0 - detail),
        common.math_node(tree, "MULTIPLY_ADD", grain, 0.3, 0.85),
    )
    tree.links.new(shade, hsv.inputs["Value"])
    tree.links.new(hsv.outputs["Color"], bsdf.inputs["Base Color"])
    height = common.math_node(
        tree,
        "MULTIPLY_ADD",
        fine,
        0.5,
        common.math_node(tree, "MULTIPLY_ADD", grain, 0.3, common.math_node(tree, "MULTIPLY", medium, 0.3)),
    )
    if config.get("ripples"):
        ripple = common.math_node(tree, "MULTIPLY", _crests(tree, a, b, 7, 3, medium, 1.5), config["ripples"])
        height = common.math_node(tree, "ADD", height, ripple)
    relief = tree.nodes.new("ShaderNodeBump")
    relief.inputs["Strength"].default_value = config["bump"]
    relief.inputs["Distance"].default_value = 0.03
    tree.links.new(height, relief.inputs["Height"])
    tree.links.new(relief.outputs["Normal"], bsdf.inputs["Normal"])
    roughness = config.get("roughness", 0.9)
    if config.get("wet"):
        wet = common.ramp(tree, medium, [(at, (roughness,) * 3), (at + 0.07, (0.12, 0.12, 0.12))])
        tree.links.new(wet, bsdf.inputs["Roughness"])
    else:
        bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
    return material


def _water_material(kind: str):
    material, tree, bsdf, _ = common.new_material(f"Water-{kind}")
    a, b = _angles(tree)
    swell = _torus_noise(tree, a, b, 0.9, 3.0, 0.5, 2.3, stretch=0.55)
    chop = _torus_noise(tree, a, b, 4.5, 4.0, 0.6, 6.1, stretch=0.8)
    crest = common.math_node(
        tree,
        "MAXIMUM",
        _crests(tree, a, b, 9, 4, swell, 5.0),
        common.math_node(tree, "MULTIPLY", _crests(tree, a, b, -4, 11, chop, 6.0), 0.7),
    )
    deep = {"ocean": (0.04, 0.22, 0.36), "lake": (0.08, 0.32, 0.40), "highSeas": (0.02, 0.15, 0.30)}[kind]
    light = {"ocean": (0.10, 0.40, 0.52), "lake": (0.16, 0.48, 0.52), "highSeas": (0.06, 0.28, 0.44)}[kind]
    color = common.ramp(tree, swell, [(0.2, deep), (0.9, light)])
    color = common.mix_color(tree, common.math_node(tree, "MULTIPLY", crest, 0.14), color, (0.62, 0.80, 0.84))
    tree.links.new(color, bsdf.inputs["Base Color"])
    height = common.math_node(
        tree,
        "MULTIPLY_ADD",
        crest,
        0.5,
        common.math_node(tree, "MULTIPLY_ADD", chop, 0.3, common.math_node(tree, "MULTIPLY", swell, 0.4)),
    )
    relief = tree.nodes.new("ShaderNodeBump")
    relief.inputs["Strength"].default_value = 0.28
    relief.inputs["Distance"].default_value = 0.022
    tree.links.new(height, relief.inputs["Height"])
    tree.links.new(relief.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.16
    bsdf.inputs["Specular IOR Level"].default_value = 0.3
    return material


def _mesh(name: str, bm, mat):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    return mesh


def _prototype(kind: str, mat, seed: int):
    """Unit-sized meshes standing on z=0; instances scale them to their real size."""
    bm = bmesh.new()
    if kind in ("bush", "rock", "ice"):
        bmesh.ops.create_icosphere(bm, subdivisions=2 if kind == "bush" else 1, radius=1.0)
        common.displace(bm, {"bush": 0.22, "rock": 0.35, "ice": 0.3}[kind], 1.8, seed)
        squash = {"bush": 0.8, "rock": 0.55, "ice": 0.7}[kind]
        bmesh.ops.scale(bm, vec=(1.0, 1.0, squash), verts=bm.verts)
        bmesh.ops.translate(bm, vec=(0.0, 0.0, squash * 0.6), verts=bm.verts)
    elif kind in ("tuft", "reed"):
        blades = 7 if kind == "tuft" else 6
        for index in range(blades):
            angle = index / blades * 2.0 * math.pi + seed
            lean = 0.35 if kind == "tuft" else 0.12
            matrix = Matrix.Translation(
                (math.cos(angle) * 0.15, math.sin(angle) * 0.15, 0.5)
            ) @ Matrix.Rotation(lean, 4, (math.sin(angle), -math.cos(angle), 0.0))
            bmesh.ops.create_cone(
                bm,
                cap_ends=False,
                cap_tris=False,
                segments=4,
                radius1=0.09 if kind == "tuft" else 0.05,
                radius2=0.0,
                depth=1.0,
                matrix=matrix,
            )
    elif kind == "flower":
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0, matrix=Matrix.Translation((0.0, 0.0, 1.6)))
    return _mesh(f"{kind}-{seed}", bm, mat)


def _scatter(kind_config, rng, margin: float = 0.3) -> None:
    for index, (kind, count, (low, high), colors) in enumerate(kind_config):
        meshes = []
        for variant, color in enumerate(colors):
            mat = common.material(
                f"{kind}-{variant}",
                color,
                roughness=0.8 if kind != "ice" else 0.25,
                variation=0.12,
                scale=8.0,
                random_tint=0.6 if kind in ("bush", "tuft") else 0.2,
                translucency=0.15 if kind in ("bush", "tuft", "reed") else 0.0,
            )
            meshes.append(_prototype(kind, mat, index * 13 + variant * 7 + 1))
        for _ in range(count):
            x, y = rng.uniform(-HALF, HALF), rng.uniform(-HALF, HALF)
            size, turn, mesh = rng.uniform(low, high), rng.uniform(0.0, 2.0 * math.pi), rng.choice(meshes)
            for dx in (-TILE, 0.0, TILE):
                for dy in (-TILE, 0.0, TILE):
                    if abs(x + dx) > HALF + margin or abs(y + dy) > HALF + margin:
                        continue
                    obj = common.link(bpy.data.objects.new(f"{kind}", mesh))
                    obj.location = (x + dx, y + dy, 0.0)
                    obj.rotation_euler = (0.0, 0.0, turn)
                    obj.scale = (size, size, size)


def build_tile(job: dict, view, rng) -> None:
    kind = job["params"]["type"]
    water = kind in ("ocean", "lake", "highSeas")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=TILE * 1.5)
    ground = common.from_bmesh(
        "Ground", bm, _water_material(kind) if water else _ground_material(kind), smooth=False
    )
    ground.location = (0.0, 0.0, 0.0)
    if not water:
        _scatter(SCATTER.get(kind, []), rng)
