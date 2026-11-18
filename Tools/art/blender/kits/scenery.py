"""Procedural shoreline, river, cloud, field and panoramic background assets."""

from __future__ import annotations

import math
import re

import bmesh

from . import common
from .common import HALF, TILE


def _mat(name, color, **kwargs):
    kwargs.setdefault("variation", 0.1)
    return common.material(name, color, **kwargs)


def _polygon(name, points, z, material):
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, z)) for x, y in points]
    bm.faces.new(verts)
    return common.from_bmesh(name, bm, material, smooth=False)


def build_beach(job: dict, view, rng) -> None:
    kind = job["params"]["type"]
    sand = _mat(
        "warm coastal sand", (0.78, 0.63, 0.39), roughness=0.94, variation=0.12, scale=12.0, bump=0.08
    )
    wet = _mat("wet shoreline", (0.55, 0.48, 0.34), roughness=0.58, variation=0.08)
    palm = _mat("driftwood", (0.30, 0.19, 0.10), roughness=0.9)
    if kind == "center0":
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=TILE / 2)
        common.from_bmesh("beach center", bm, sand, smooth=False)
        return
    match = re.match(r"(edge|corner)(\d+)", kind)
    if not match:
        return
    form, raw_index = match.groups()
    index = int(raw_index)
    turn = (index % 4) * math.pi / 2
    if form == "edge":
        points = [
            (-1.0, -0.75),
            (-0.55, -0.68),
            (-0.10, -0.83),
            (0.32, -0.73),
            (0.70, -0.84),
            (1.0, -0.72),
            (1.0, -1.0),
            (-1.0, -1.0),
        ]
    else:
        points = [
            (-1.0, -0.80),
            (-0.65, -0.60),
            (-0.46, -0.35),
            (-0.18, -0.19),
            (-0.35, -0.05),
            (-0.68, -0.20),
            (-0.86, -0.47),
            (-1.0, -0.58),
        ]
    rotated = [
        (x * math.cos(turn) - y * math.sin(turn), x * math.sin(turn) + y * math.cos(turn)) for x, y in points
    ]
    _polygon("shore sand", rotated, 0.018, sand)
    if form == "edge":
        for step in range(8):
            x = -0.78 + step * 0.22
            y = -0.73 + rng.uniform(-0.035, 0.035)
            common.sphere("wet sand", 0.07, (x, y, 0.027), wet, scale=(1.5, 0.42, 0.12), subdivisions=2)
    for _ in range(4 if form == "corner" else 2):
        x, y = rng.choice(rotated)
        common.sphere(
            "beach pebble",
            rng.uniform(0.025, 0.055),
            (x, y, 0.035),
            palm,
            scale=(1.3, 0.8, 0.45),
            subdivisions=1,
            jitter=0.01,
            seed=rng.randrange(50000),
        )


def build_river(job: dict, view, rng) -> None:
    style = job["params"]["style"]
    water = _mat("river water", (0.06, 0.31, 0.44), roughness=0.22, metallic=0.12)
    bank = _mat("river bank", (0.45, 0.36, 0.21), roughness=0.92)
    for direction, digit in enumerate(style):
        if digit == "0":
            continue
        angle = direction * math.pi / 2 + math.pi / 4
        end = (math.cos(angle) * HALF, math.sin(angle) * HALF, 0.025)
        bend = (
            math.cos(angle) * 0.18 + rng.uniform(-0.12, 0.12),
            math.sin(angle) * 0.18 + rng.uniform(-0.12, 0.12),
            0.03,
        )
        width = 0.075 if digit == "1" else 0.115
        common.limb("sandy river bank", (0.0, 0.0, 0.018), bend, width * 1.65, width * 1.25, bank)
        common.limb("river channel", (0.0, 0.0, 0.035), bend, width, width * 0.82, water)
        common.limb("river channel", bend, end, width * 0.82, width * 0.52, water)
    if any(digit != "0" for digit in style):
        common.sphere("river pool", 0.12, (0.0, 0.0, 0.035), water, scale=(1.0, 0.8, 0.22), subdivisions=2)
        stones = _mat("river stones", (0.48, 0.45, 0.38), roughness=0.84)
        for _ in range(5):
            x, y = rng.uniform(-0.65, 0.65), rng.uniform(-0.4, 0.4)
            common.sphere(
                "river pebble",
                rng.uniform(0.018, 0.033),
                (x, y, 0.035),
                stones,
                scale=(1.2, 0.8, 0.35),
                subdivisions=1,
                seed=rng.randrange(50000),
            )


def build_delta(job: dict, view, rng) -> None:
    kind = job["params"]["type"]
    direction = kind.split("_")[1] if "_" in kind else "NE"
    scale = 1.0 if kind.endswith("large") else 0.68
    water = _mat("delta water", (0.06, 0.28, 0.38), roughness=0.25, metallic=0.1)
    sand = _mat("delta silt", (0.67, 0.55, 0.34), roughness=0.94)
    rotation = {"NE": 0.0, "SE": -math.pi / 2, "SW": math.pi, "NW": math.pi / 2}.get(direction, 0.0)
    for branch in range(3):
        lateral = (branch - 1) * 0.24 * scale
        start = (-0.9, lateral * 0.25, 0.035)
        split = (-0.20, lateral, 0.035)
        end = (0.97, lateral * 1.55, 0.035)

        def turn(point):
            x, y, z = point
            return (
                x * math.cos(rotation) - y * math.sin(rotation),
                x * math.sin(rotation) + y * math.cos(rotation),
                z,
            )

        a, b, c = map(turn, (start, split, end))
        width = (0.11 if branch == 1 else 0.07) * scale
        common.limb("delta silt bank", a, b, width * 1.8, width * 1.45, sand)
        common.limb("delta channel", a, b, width, width * 0.84, water)
        common.limb("delta silt bank", b, c, width * 0.84, width * 0.45, sand)
        common.limb("delta channel", b, c, width * 0.52, width * 0.30, water)


def build_river_texture(job: dict, view, rng) -> None:
    kind = job["params"]["type"]
    if kind == "center0":
        water = _mat(
            "river texture water", (0.10, 0.36, 0.48), roughness=0.28, metallic=0.1, variation=0.04, scale=4
        )
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=TILE * 1.5)
        common.from_bmesh("river texture", bm, water, smooth=False)
        for _ in range(18):
            x, y = rng.uniform(-0.92, 0.92), rng.uniform(-0.45, 0.45)
            common.limb(
                "water ripple",
                (x, y, 0.012),
                (x + rng.uniform(0.05, 0.22), y, 0.012),
                0.012,
                0.009,
                _mat("ripple", (0.38, 0.66, 0.69), roughness=0.3),
                segments=5,
            )
    else:
        pebble = _mat("riverbed gravel", (0.48, 0.42, 0.32), roughness=0.96, variation=0.15)
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=TILE * 1.5)
        common.from_bmesh("riverbed", bm, pebble, smooth=False)
        for _ in range(55):
            x, y = rng.uniform(-1.4, 1.4), rng.uniform(-1.4, 1.4)
            size = rng.uniform(0.025, 0.075)
            common.sphere(
                "riverbed pebble",
                size,
                (x, y, size * 0.36),
                _mat("stone", rng.choice([(0.38, 0.34, 0.28), (0.60, 0.52, 0.40)]), roughness=0.95),
                scale=(1.3, 0.9, 0.45),
                subdivisions=1,
                jitter=0.01,
                seed=rng.randrange(50000),
            )


def build_plow(job: dict, view, rng) -> None:
    soil = _mat("turned earth", (0.38, 0.27, 0.13), roughness=0.96)
    furrow = _mat("furrow shadow", (0.20, 0.15, 0.08), roughness=0.98)
    for row in range(-4, 5):
        offset = row * 0.19
        start = (-0.95, offset * 0.42, 0.025)
        end = (0.95, offset * 0.42 + 0.22, 0.026)
        common.limb("plowed ridge", start, end, 0.035, 0.032, soil, segments=7)
        common.limb(
            "plow furrow",
            (start[0], start[1] - 0.045, 0.024),
            (end[0], end[1] - 0.045, 0.024),
            0.016,
            0.014,
            furrow,
            segments=6,
        )


def build_clouds(job: dict, view, rng) -> None:
    cloud = [
        _mat("cloud white", (0.84, 0.90, 0.96), roughness=0.88, translucency=0.16),
        _mat("cloud shadow", (0.62, 0.73, 0.82), roughness=0.92, translucency=0.12),
    ]
    clusters = [(-0.62, -0.02, 0.15), (-0.12, 0.18, 0.18), (0.45, -0.08, 0.16), (0.78, 0.22, 0.11)]
    for cx, cy, scale in clusters:
        for _ in range(rng.randint(4, 7)):
            x = cx + rng.uniform(-0.16, 0.16) * scale / 0.16
            y = cy + rng.uniform(-0.11, 0.11)
            radius = scale * rng.uniform(0.55, 1.15)
            common.sphere(
                "cloud puff",
                radius,
                (x, y, rng.uniform(0.04, 0.12)),
                rng.choice(cloud),
                scale=(1.1, 0.76, 0.48),
                subdivisions=2,
                jitter=0.012,
                seed=rng.randrange(50000),
            )


def build_native_land(job: dict, view, rng) -> None:
    wood = _mat("native land marker", (0.38, 0.25, 0.12), roughness=0.9)
    red = _mat("marker pigment", (0.63, 0.17, 0.08), roughness=0.85)
    common.limb("carved pole", (0.0, 0.0, 0.0), (0.0, 0.0, 0.75), 0.055, 0.045, wood)
    for side in (-1, 1):
        common.limb("land marker arms", (0.0, 0.0, 0.48), (side * 0.25, 0.0, 0.60), 0.045, 0.035, wood)
        common.sphere(
            "painted mark", 0.055, (side * 0.13, -0.055, 0.42), red, scale=(1.0, 0.28, 0.7), subdivisions=2
        )


def build_building_background(job: dict, view, rng) -> None:
    kind = job["params"]["type"]
    grass = _mat("distant fields", (0.31, 0.40, 0.19), roughness=0.95, variation=0.2)
    timber = _mat("distant timber", (0.30, 0.20, 0.11), roughness=0.9)
    plaster = _mat("distant plaster", (0.73, 0.67, 0.53), roughness=0.9)
    fort = "fort" in kind or "stockade" in kind
    common.box("panoramic ground", (12.0, 1.1, 0.06), (0.0, 0.0, 0.0), grass)
    for index in range(13):
        x = -5.4 + index * 0.9
        height = rng.uniform(0.55, 1.1)
        wall = timber if index % 3 else plaster
        common.box(
            "settlement silhouette",
            (rng.uniform(0.42, 0.78), 0.25, height),
            (x, 0.30, 0.07 + height / 2),
            wall,
            bevel=0.02,
        )
        if index % 2 == 0:
            common.cylinder(
                "distant roof",
                0.42,
                0.48,
                (x, 0.30, 0.07 + height + 0.15),
                _mat("roof", (0.27, 0.18, 0.12)),
                radius2=0.0,
                segments=4,
                rotation=(0.0, 0.0, math.pi / 4),
            )
    if fort:
        for x in (-5.8, 5.8):
            common.box("fort tower", (0.55, 0.55, 1.6), (x, -0.10, 0.87), timber, bevel=0.04)
            common.cylinder(
                "tower roof",
                0.42,
                0.55,
                (x, -0.10, 1.92),
                _mat("tower roof", (0.23, 0.16, 0.11)),
                radius2=0.0,
                segments=8,
            )
    for _ in range(24):
        x = rng.uniform(-5.6, 5.6)
        common.sphere(
            "distant tree",
            rng.uniform(0.18, 0.34),
            (x, 0.02, rng.uniform(0.22, 0.40)),
            _mat("distant leaves", rng.choice([(0.18, 0.30, 0.10), (0.25, 0.35, 0.12)])),
            scale=(1.2, 0.8, 1.0),
            subdivisions=2,
            seed=rng.randrange(50000),
        )
