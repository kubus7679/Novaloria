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
    # FreeCol bit order: edges NE, SE, SW, NW; corners N, E, S, W.
    for direction in range(4):
        if not index & (1 << direction):
            continue
        turn = -direction * math.pi / 2

        def rotate(points, turn=turn):
            return [
                (x * math.cos(turn) - y * math.sin(turn),
                 x * math.sin(turn) + y * math.cos(turn))
                for x, y in points
            ]

        if form == "edge":
            coast = [(x, 0.77 + 0.035 * math.sin(step * 1.8))
                     for step, x in enumerate((-1.0, -0.6, -0.2, 0.2, 0.6, 1.0))]
            points = [(-1.0, 1.0), *coast, (1.0, 1.0)]
        else:
            coast = [(-1.0, 0.67), (-0.91, 0.76), (-0.78, 0.84), (-0.67, 1.0)]
            points = [(-1.0, 1.0), *coast]
        _polygon("shore sand", rotate(points), 0.0, sand)
        wet_strip = coast + [(x * 0.96, y * 0.96) for x, y in reversed(coast)]
        _polygon("wet shoreline", rotate(wet_strip), 0.0, wet)


def build_river(job: dict, view, rng) -> None:
    style = job["params"]["style"]
    water = _mat("river water", (0.06, 0.31, 0.44), roughness=0.22, metallic=0.12)
    bank = _mat("river bank", (0.45, 0.36, 0.21), roughness=0.92)
    for direction, digit in enumerate(style):
        if digit == "0":
            continue
        # Axis-aligned world edges project to the diamond's NE, SE, SW, NW sides.
        dx, dy = ((0, 1), (1, 0), (0, -1), (-1, 0))[direction]
        width = 0.065 if digit == "1" else 0.105
        bend = rng.uniform(-0.10, 0.10)
        centers = []
        for step in range(33):
            t = step / 32
            lateral = bend * math.sin(math.pi * t) ** 2
            centers.append((dx * HALF * t - dy * lateral, dy * HALF * t + dx * lateral))
        for name, low, high, material in (
            ("river channel", -width, width, water),
            ("left river bank", -width * 1.5, -width, bank),
            ("right river bank", width, width * 1.5, bank),
        ):
            bm = bmesh.new()
            previous = None
            for step, (x, y) in enumerate(centers):
                t = step / 32
                slope = bend * math.pi * math.sin(2 * math.pi * t)
                tx, ty = dx * HALF - dy * slope, dy * HALF + dx * slope
                length = math.hypot(tx, ty)
                pair = [bm.verts.new((x - ty / length * w, y + tx / length * w, 0.0))
                        for w in (low, high)]
                if previous:
                    bm.faces.new((previous[0], pair[0], pair[1], previous[1]))
                previous = pair
            common.from_bmesh(name, bm, material, smooth=False)
    if any(digit != "0" for digit in style):
        _polygon("river junction", [
            (0.108 * math.cos(i * math.tau / 32), 0.108 * math.sin(i * math.tau / 32))
            for i in range(32)
        ], 0.001, water)
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
    soils = [
        _mat(f"earth tone {i}", color, roughness=0.96, variation=0.28, scale=18, bump=0.2)
        for i, color in enumerate(((0.37, 0.26, 0.14), (0.46, 0.33, 0.18), (0.53, 0.40, 0.24)))
    ]
    furrow = _mat("furrow shadow", (0.24, 0.18, 0.11), roughness=0.98, variation=0.2)
    for row in range(-6, 7):
        y = row * 0.12
        edge = 0.91 - 0.05 * abs(row) / 6
        points = [(-edge + step * edge / 16, y + 0.018 * math.sin(step * 0.65 + row))
                  for step in range(33)]
        _polygon("plow furrow", points + [(x, y + 0.105) for x, y in reversed(points)], 0.0, furrow)
        _polygon("plowed ridge", points + [(x, y + 0.070) for x, y in reversed(points)],
                 0.001, rng.choice(soils))
    for _ in range(95):
        x, y = rng.uniform(-0.84, 0.84), rng.uniform(-0.7, 0.7)
        common.sphere("soil clod", rng.uniform(0.008, 0.024), (x, y, 0.012),
                      rng.choice(soils), scale=(1.4, 0.8, 0.45), subdivisions=1)


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
