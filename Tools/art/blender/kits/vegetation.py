"""Tree and relief overlays for the isometric map."""

from __future__ import annotations

import math

import bmesh

from . import common
from .common import HALF


def _tree_material(name: str, colors, roughness: float = 0.82):
    mats = [
        common.material(
            f"{name}-{index}",
            color,
            roughness=roughness,
            variation=0.18,
            scale=12.0,
            random_tint=0.55,
            translucency=0.12,
        )
        for index, color in enumerate(colors)
    ]
    return mats


def _broadleaf(x: float, y: float, scale: float, rng, materials, bark):
    common.limb("tree trunk", (x, y, 0.0), (x, y, scale * 1.05), scale * 0.10, scale * 0.055, bark)
    for _ in range(3):
        angle = rng.uniform(0, math.tau)
        z = scale * rng.uniform(0.55, 0.94)
        end = (x + math.cos(angle) * scale * 0.34, y + math.sin(angle) * scale * 0.34, z + scale * 0.25)
        common.limb("tree branch", (x, y, z), end, scale * 0.045, scale * 0.025, bark, segments=8)
    for _ in range(rng.randint(7, 10)):
        angle = rng.uniform(0, math.tau)
        radius = scale * rng.uniform(0.12, 0.48)
        z = scale * rng.uniform(0.82, 1.45)
        size = scale * rng.uniform(0.28, 0.47)
        common.sphere(
            "leaf crown",
            size,
            (x + math.cos(angle) * radius, y + math.sin(angle) * radius, z),
            rng.choice(materials),
            scale=(1.0, rng.uniform(0.8, 1.15), rng.uniform(0.82, 1.12)),
            subdivisions=2,
            jitter=0.035,
            seed=rng.randrange(50000),
        )


def _conifer(x: float, y: float, scale: float, rng, materials, bark):
    common.cylinder(
        "conifer trunk",
        scale * 0.075,
        scale * 1.45,
        (x, y, scale * 0.72),
        bark,
        radius2=scale * 0.025,
        segments=9,
    )
    for tier in range(4):
        z = scale * (0.50 + tier * 0.28)
        radius = scale * (0.51 - tier * 0.085)
        common.cylinder(
            "conifer boughs",
            radius,
            scale * 0.76,
            (x, y, z),
            rng.choice(materials),
            radius2=0.0,
            segments=11,
            smooth=False,
        )


def _palm(x: float, y: float, scale: float, rng, leaves, bark):
    top = scale * 1.65
    common.limb("palm trunk", (x, y, 0.0), (x + scale * 0.10, y, top), scale * 0.095, scale * 0.055, bark)
    for frond in range(7):
        angle = frond * math.tau / 7 + rng.uniform(-0.15, 0.15)
        length = scale * rng.uniform(0.52, 0.78)
        tip = (x + scale * 0.10 + math.cos(angle) * length,
               y + math.sin(angle) * length, top - scale * rng.uniform(0.12, 0.28))
        common.limb("palm frond", (x + scale * 0.10, y, top), tip, scale * 0.035, scale * 0.008,
                    rng.choice(leaves), segments=8)
        for leaflet in range(1, 5):
            t = leaflet / 5
            stem = (x + scale * 0.10 + math.cos(angle) * length * t,
                    y + math.sin(angle) * length * t, top - scale * 0.08 - scale * 0.12 * t)
            for side in (-1, 1):
                end = (stem[0] - math.sin(angle) * side * scale * 0.16,
                       stem[1] + math.cos(angle) * side * scale * 0.16, stem[2] - scale * 0.06)
                common.limb("palm leaflet", stem, end, scale * 0.012, scale * 0.003,
                            rng.choice(leaves), segments=5, rounded=False)


def build_forest(job: dict, view, rng) -> None:
    kind = job["params"]["type"]
    mixed = kind == "mixed"
    coniferous = kind in {"conifer", "boreal"}
    tropical = kind in {"tropical", "rain"}
    foliage = _tree_material(
        "leaf",
        [(0.10, 0.30, 0.08), (0.18, 0.40, 0.09), (0.28, 0.46, 0.11), (0.39, 0.49, 0.14)]
        if tropical
        else [(0.13, 0.25, 0.075), (0.20, 0.34, 0.09), (0.31, 0.39, 0.105), (0.38, 0.43, 0.15)],
    )
    conifer = _tree_material("pine", [(0.055, 0.18, 0.12), (0.08, 0.24, 0.14), (0.13, 0.29, 0.16)])
    bark = common.material("bark", (0.29, 0.17, 0.09), roughness=0.9, variation=0.2, scale=18.0)
    common.shadow_catcher(size=12.0)
    count = 11 if tropical else (8 if mixed else 10)
    for index in range(count):
        x = rng.uniform(-0.74, 0.74)
        y = rng.uniform(-0.54, 0.48)
        scale = rng.uniform(0.62, 0.94) if index < 3 else rng.uniform(0.42, 0.73)
        if coniferous or (mixed and rng.random() < 0.43):
            _conifer(x, y, scale, rng, conifer, bark)
        elif tropical and rng.random() < 0.65:
            _palm(x, y, scale, rng, foliage, bark)
        else:
            _broadleaf(x, y, scale, rng, foliage, bark)
    undergrowth = _tree_material("undergrowth", [(0.15, 0.25, 0.07), (0.24, 0.32, 0.08)])
    for _ in range(11):
        x, y = rng.uniform(-0.9, 0.9), rng.uniform(-0.6, 0.55)
        common.sphere(
            "undergrowth",
            rng.uniform(0.10, 0.20),
            (x, y, 0.08),
            rng.choice(undergrowth),
            scale=(1.3, 0.9, 0.7),
            subdivisions=2,
            jitter=0.02,
            seed=rng.randrange(50000),
        )


def _relief_material(mountain: bool):
    material, tree, bsdf, output = common.new_material("Mountain" if mountain else "Hill")
    geometry = tree.nodes.new("ShaderNodeNewGeometry")
    separate = tree.nodes.new("ShaderNodeSeparateXYZ")
    tree.links.new(geometry.outputs["Position"], separate.inputs[0])
    height = separate.outputs["Z"]
    # Use a compact slope palette, with snow confined to the highest mountain faces.
    noise = common.noise_texture(tree, geometry.outputs["Position"], 4.0, 3.0, 0.58)
    field = common.math_node(tree, "MULTIPLY_ADD", noise, 0.12, height)
    if mountain:
        colors = [
            (0.0, (0.20, 0.26, 0.23)),
            (0.22, (0.31, 0.34, 0.30)),
            (0.48, (0.40, 0.38, 0.32)),
            (0.72, (0.74, 0.73, 0.68)),
            (0.88, (0.96, 0.97, 0.98)),
        ]
    else:
        colors = [
            (0.0, (0.20, 0.29, 0.12)),
            (0.18, (0.31, 0.36, 0.16)),
            (0.42, (0.42, 0.37, 0.24)),
            (0.7, (0.52, 0.45, 0.32)),
        ]
    color = common.ramp(tree, field, colors)
    tree.links.new(color, bsdf.inputs["Base Color"])
    tree.links.new(noise, bsdf.inputs["Roughness"])
    bsdf.inputs["Roughness"].default_value = 0.88
    alpha = common.map_range(tree, height, 0.006, 0.045, 0.0, 1.0)
    tree.links.new(alpha, bsdf.inputs["Alpha"])
    material.surface_render_method = "DITHERED"
    return material


def _heightfield(mountain: bool, rng):
    segments = 56
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=segments, y_segments=segments, size=HALF)
    # A rounded, asymmetrical double summit reads as a landform rather than a geometric cone.
    peaks = [
        (
            rng.uniform(-0.30, -0.02),
            rng.uniform(-0.12, 0.16),
            rng.uniform(0.72, 0.93),
            rng.uniform(0.42, 0.58),
            rng.uniform(0.38, 0.54),
        )
    ]
    if mountain:
        peaks.append(
            (
                rng.uniform(0.05, 0.30),
                rng.uniform(-0.06, 0.18),
                rng.uniform(0.48, 0.72),
                rng.uniform(0.30, 0.40),
                rng.uniform(0.34, 0.46),
            )
        )
    else:
        peaks[0] = (*peaks[0][:2], rng.uniform(0.22, 0.30), 0.70, 0.58)
    for vertex in bm.verts:
        x, y = vertex.co.x, vertex.co.y
        diamond = max(0.0, 1.0 - (abs(x) + abs(y)) / HALF)
        z = 0.0
        for px, py, amplitude, wx, wy in peaks:
            q = ((x - px) / wx) ** 2 + ((y - py) / wy) ** 2
            z = max(z, amplitude * math.exp(-2.2 * q))
        if mountain:
            ridge = abs(math.sin(13.0 * x + 2.5 * math.sin(5.0 * y)) * math.sin(11.0 * y + math.sin(7.0 * x)))
            detail = math.sin(27.0 * x + 3.0 * math.cos(19.0 * y)) * math.sin(23.0 * y)
            z += (ridge * 0.15 + detail * 0.035) * min(1.0, z * 2.0)
            z = max(0.0, z)
        else:
            z += 0.008 * math.sin(17.0 * x + 2.0 * math.cos(9.0 * y)) * math.sin(14.0 * y)
            z = max(0.0, z)
        vertex.co.z = z * min(1.0, diamond * 5.0)
    bmesh.ops.delete(bm, geom=[face for face in bm.faces if not face.is_valid], context="FACES")
    return bm


def build_relief(job: dict, view, rng) -> None:
    mountain = job["params"]["type"] == "mountains"
    material = _relief_material(mountain)
    bm = _heightfield(mountain, rng)
    obj = common.from_bmesh("Mountain relief" if mountain else "Hills relief", bm, material)
    for face in obj.data.polygons:
        face.use_smooth = True
    common.shadow_catcher(size=12.0)
    rock = common.material("foothill rock", (0.39, 0.36, 0.31), roughness=0.92, variation=0.25, scale=20)
    for _ in range(16 if mountain else 10):
        x, y = rng.uniform(-0.85, 0.85), rng.uniform(-0.55, 0.55)
        if abs(x) + abs(y) > 1.06:
            continue
        size = rng.uniform(0.055, 0.12)
        common.sphere(
            "foothill stone",
            size,
            (x, y, size * 0.28),
            rock,
            scale=(1.0, 0.8, 0.55),
            subdivisions=1,
            jitter=0.015,
            seed=rng.randrange(50000),
        )
