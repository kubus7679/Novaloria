"""Sailing ship and covered wagon props."""

from __future__ import annotations

import math
from contextlib import suppress

import bmesh

from . import common


def _mat(name, color, **kwargs):
    kwargs.setdefault("variation", 0.12)
    return common.material(name, color, **kwargs)


def _hull(name, stations, material):
    bm = bmesh.new()
    ring_size = 8
    verts = []
    for x, breadth, keel, deck in stations:
        profile = [
            (0.0, keel),
            (-breadth * 0.72, keel + 0.06),
            (-breadth, (keel + deck) * 0.52),
            (-breadth * 0.86, deck),
            (-breadth * 0.48, deck + 0.03),
            (breadth * 0.48, deck + 0.03),
            (breadth * 0.86, deck),
            (breadth, (keel + deck) * 0.52),
        ]
        for y, z in profile:
            verts.append(bm.verts.new((x, y, z)))
    bm.verts.ensure_lookup_table()
    for station in range(len(stations) - 1):
        for index in range(ring_size):
            a = station * ring_size + index
            b = station * ring_size + (index + 1) % ring_size
            with suppress(ValueError):
                bm.faces.new((verts[a], verts[b], verts[b + ring_size], verts[a + ring_size]))
    bm.faces.new(tuple(verts[index] for index in range(ring_size)))
    bm.faces.new(
        tuple(verts[(len(stations) - 1) * ring_size + index] for index in reversed(range(ring_size)))
    )
    return common.from_bmesh(name, bm, material, smooth=True)


def _sail(name, mast_x: float, z0: float, z1: float, width: float, material, billow: float):
    bm = bmesh.new()
    rows, cols = 8, 8
    grid = []
    for row in range(rows + 1):
        v = row / rows
        row_verts = []
        row_width = width * (1.0 - 0.48 * v)
        for col in range(cols + 1):
            u = col / cols * 2.0 - 1.0
            # The shallow convexity catches the light like filled canvas.
            y = -0.025 - billow * math.sin(math.pi * v) * (1.0 - u * u)
            z = z0 + (z1 - z0) * v
            x = mast_x + u * row_width
            row_verts.append(bm.verts.new((x, y, z)))
        grid.append(row_verts)
    for row in range(rows):
        for col in range(cols):
            bm.faces.new((grid[row][col], grid[row][col + 1], grid[row + 1][col + 1], grid[row + 1][col]))
    obj = common.from_bmesh(name, bm, material)
    solidify = obj.modifiers.new("Canvas thickness", "SOLIDIFY")
    solidify.thickness = 0.012
    return obj


def build_ship(job: dict, view, rng) -> None:
    ship_type = job["params"].get("type", "caravel")
    ghost = ship_type == "flyingDutchman"
    oak_color = (
        (0.20, 0.25, 0.22)
        if ghost
        else (0.19, 0.095, 0.045)
        if ship_type in {"privateer", "manOWar"}
        else (0.25, 0.12, 0.055)
    )
    oak = _mat("hull oak", oak_color, roughness=0.72, bands=11.0, bump=0.18)
    dark = _mat("keel timber", (0.13, 0.075, 0.04), roughness=0.8, bands=8.0)
    deck = _mat("weathered deck", (0.59, 0.39, 0.20), roughness=0.84, bands=22.0, bump=0.12)
    sail_color = (
        (0.47, 0.55, 0.45) if ghost else (0.76, 0.73, 0.61) if ship_type == "manOWar" else (0.90, 0.82, 0.64)
    )
    canvas = _mat("sail canvas", sail_color, roughness=0.9, variation=0.08)
    rope = _mat("hemp rope", (0.39, 0.27, 0.14), roughness=0.92)
    brass = _mat("brass fittings", (0.55, 0.39, 0.13), roughness=0.28, metallic=0.6)
    sea = _mat("waterline", (0.09, 0.28, 0.35), roughness=0.25, metallic=0.15)
    stations = [
        (-0.95, 0.03, 0.18, 0.44),
        (-0.75, 0.26, 0.10, 0.53),
        (-0.40, 0.39, 0.06, 0.58),
        (0.10, 0.40, 0.06, 0.61),
        (0.53, 0.33, 0.12, 0.68),
        (0.78, 0.22, 0.20, 0.77),
        (0.88, 0.10, 0.31, 0.88),
    ]
    _hull("caravel hull", stations, oak)
    _hull(
        "keel",
        [
            (-0.88, 0.04, 0.08, 0.17),
            (-0.65, 0.06, 0.06, 0.20),
            (0.52, 0.06, 0.10, 0.25),
            (0.77, 0.04, 0.18, 0.34),
        ],
        dark,
    )
    common.box("deck", (1.52, 0.60, 0.08), (-0.02, 0.0, 0.56), deck, bevel=0.035)
    common.box("forecastle", (0.34, 0.42, 0.21), (-0.64, 0.0, 0.69), oak, bevel=0.025)
    common.box("stern castle", (0.30, 0.43, 0.40), (0.61, 0.0, 0.83), oak, bevel=0.035)
    for y in (-0.17, 0.17):
        for x in (-0.60, 0.59):
            common.sphere(
                "porthole",
                0.027,
                (x, y, 0.80 if x > 0 else 0.67),
                brass,
                scale=(1.0, 0.35, 1.0),
                subdivisions=2,
            )
    common.limb("waterline stripe", (-0.82, -0.31, 0.36), (0.72, -0.24, 0.50), 0.035, 0.025, sea, segments=8)
    mast_data = [(-0.54, 1.72, 0.38), (0.03, 2.15, 0.48), (0.55, 1.62, 0.32)]
    if ship_type in {"galleon", "manOWar"}:
        mast_data.insert(2, (0.31, 1.85, 0.28))
    for mast_index, (x, height, sail_width) in enumerate(mast_data):
        common.limb(
            "mast",
            (x, 0.0, 0.59),
            (x, 0.0, height),
            0.055 if mast_index == 1 else 0.045,
            0.03,
            dark,
            segments=12,
        )
        if mast_index != 1:
            yard_z = height * 0.68
            common.limb(
                "lateen yard",
                (x - sail_width, -0.04, yard_z - 0.15),
                (x + sail_width, -0.04, yard_z + 0.15),
                0.022,
                0.018,
                dark,
                segments=10,
            )
            _sail("lateen sail", x, 0.70, yard_z, sail_width, canvas, rng.uniform(0.06, 0.11))
        else:
            for level, width in ((0.69, 0.44), (1.13, 0.29), (1.53, 0.18)):
                yard_z = level + 0.59
                common.limb(
                    "square yard",
                    (x - width, -0.02, yard_z),
                    (x + width, -0.02, yard_z),
                    0.022,
                    0.022,
                    dark,
                    segments=10,
                )
                _sail("square sail", x, yard_z - 0.31, yard_z, width, canvas, rng.uniform(0.05, 0.09))
        for anchor in (-0.68, 0.65):
            common.limb(
                "standing rigging",
                (anchor, -0.25, 0.62),
                (x, -0.05, height - 0.05),
                0.009,
                0.006,
                rope,
                segments=5,
                rounded=False,
            )
        if mast_index == 1:
            common.limb(
                "mast cap", (x, 0.0, height - 0.05), (x, 0.0, height + 0.14), 0.025, 0.008, dark, segments=8
            )
    common.limb("pennant spar", (0.03, 0.0, 2.17), (0.46, 0.0, 2.17), 0.014, 0.01, dark, segments=7)
    common.limb(
        "pennant",
        (0.44, -0.01, 2.16),
        (0.67, -0.01, 2.08),
        0.025,
        0.0,
        _mat("red pennant", (0.58, 0.09, 0.055)),
        segments=4,
        rounded=False,
    )
    if ship_type in {"frigate", "manOWar", "privateer"}:
        gunmetal = _mat("ship cannon", (0.19, 0.18, 0.16), metallic=0.45, roughness=0.42)
        for side in (-1, 1):
            for x in (-0.42, -0.12, 0.18, 0.45):
                common.cylinder(
                    "deck cannon",
                    0.035,
                    0.31,
                    (x, side * 0.31, 0.60),
                    gunmetal,
                    segments=10,
                    rotation=(math.pi / 2, 0.0, 0.0),
                )
                common.sphere(
                    "gun port", 0.038, (x, side * 0.36, 0.51), dark, scale=(1.0, 0.35, 0.8), subdivisions=2
                )
    if ghost:
        for side in (-1, 1):
            common.limb(
                "ghost pennant",
                (0.05, side * 0.02, 2.12),
                (0.35, side * 0.02, 1.98),
                0.035,
                0.0,
                _mat("ghost cloth", (0.43, 0.62, 0.52), translucency=0.35),
                segments=5,
                rounded=False,
            )


def build_wagon(job: dict, view, rng) -> None:
    wagon_type = job["params"].get("type", "wagonTrain")
    wood = _mat("wagon wood", (0.38, 0.22, 0.10), roughness=0.8, bands=15.0)
    dark = _mat("iron fittings", (0.13, 0.11, 0.085), roughness=0.38, metallic=0.62)
    canvas = _mat("wagon canvas", (0.84, 0.75, 0.58), roughness=0.92, variation=0.1, bump=0.06)
    common.box("wagon bed", (0.90, 0.57, 0.12), (0.0, 0.0, 0.64), wood, bevel=0.035)
    common.box("front board", (0.08, 0.59, 0.42), (-0.40, 0.0, 0.80), wood, bevel=0.02)
    common.box("rear board", (0.08, 0.59, 0.42), (0.40, 0.0, 0.80), wood, bevel=0.02)
    common.box("side rail", (0.82, 0.055, 0.25), (0.0, -0.25, 0.78), wood, bevel=0.025)
    common.box("side rail", (0.82, 0.055, 0.25), (0.0, 0.25, 0.78), wood, bevel=0.025)
    common.limb("axle", (-0.02, -0.56, 0.45), (-0.02, 0.56, 0.45), 0.055, 0.055, dark, segments=10)
    # Four spoked wheels use actual radial spokes and a sturdy wooden felloe.
    for x in (-0.29, 0.29):
        for side in (-1, 1):
            y = side * 0.48
            common.cylinder(
                "wheel rim", 0.35, 0.075, (x, y, 0.46), wood, segments=28, rotation=(math.pi / 2, 0.0, 0.0)
            )
            common.cylinder(
                "iron tire",
                0.355,
                0.022,
                (x, y + side * 0.045, 0.46),
                dark,
                segments=28,
                rotation=(math.pi / 2, 0.0, 0.0),
            )
            common.cylinder(
                "wheel hub", 0.09, 0.13, (x, y, 0.46), wood, segments=14, rotation=(math.pi / 2, 0.0, 0.0)
            )
            for spoke in range(10):
                angle = spoke * math.tau / 10
                end = (x + math.cos(angle) * 0.29, y, 0.46 + math.sin(angle) * 0.29)
                common.limb("wheel spoke", (x, y, 0.46), end, 0.022, 0.018, wood, segments=6, rounded=False)
    # Flexible hoops arch over the bed; a softly domed cloth is draped over them.
    for x in (-0.32, -0.12, 0.12, 0.32):
        points = []
        for step in range(13):
            angle = math.pi * step / 12
            points.append((x, math.cos(angle) * 0.34, 0.82 + math.sin(angle) * 0.65))
        for start, end in zip(points, points[1:], strict=False):
            common.limb("canopy bow", start, end, 0.018, 0.018, wood, segments=6, rounded=False)
    bm = bmesh.new()
    rows, cols = 10, 16
    grid = []
    for row in range(rows + 1):
        u = row / rows
        x = -0.42 + u * 0.84
        row_verts = []
        for col in range(cols + 1):
            angle = math.pi * col / cols
            y = math.cos(angle) * 0.33
            z = 0.83 + math.sin(angle) * 0.64 + 0.025 * math.sin(math.pi * u)
            row_verts.append(bm.verts.new((x, y, z)))
        grid.append(row_verts)
    for row in range(rows):
        for col in range(cols):
            bm.faces.new((grid[row][col], grid[row + 1][col], grid[row + 1][col + 1], grid[row][col + 1]))
    cloth = common.from_bmesh("wagon bonnet", bm, canvas)
    modifier = cloth.modifiers.new("Canvas thickness", "SOLIDIFY")
    modifier.thickness = 0.014
    common.limb("wagon tongue", (-0.43, 0.0, 0.57), (-0.98, 0.0, 0.43), 0.045, 0.03, wood, segments=10)
    for side in (-1, 1):
        common.limb(
            "side brace",
            (-0.40, side * 0.27, 0.50),
            (0.38, side * 0.27, 0.50),
            0.022,
            0.022,
            dark,
            segments=7,
        )
    if wagon_type in {"artillery", "damagedArtillery"}:
        iron = _mat("cannon bronze", (0.23, 0.24, 0.22), roughness=0.38, metallic=0.68)
        common.cylinder(
            "cannon barrel",
            0.11,
            0.86,
            (-0.08, 0.0, 1.35),
            iron,
            radius2=0.075,
            segments=16,
            rotation=(0.0, math.radians(78), 0.0),
        )
        common.cylinder(
            "cannon muzzle",
            0.12,
            0.09,
            (-0.26, 0.0, 1.55),
            dark,
            segments=16,
            rotation=(0.0, math.radians(78), 0.0),
        )
        for side in (-1, 1):
            common.cylinder(
                "cannon carriage wheel",
                0.18,
                0.08,
                (-0.02, side * 0.29, 1.05),
                wood,
                segments=18,
                rotation=(math.pi / 2, 0.0, 0.0),
            )
        if wagon_type == "damagedArtillery":
            common.limb(
                "broken carriage", (0.18, -0.34, 1.12), (0.47, -0.36, 0.82), 0.035, 0.022, wood, segments=8
            )
    elif wagon_type == "treasureTrain":
        gold = _mat("treasure brass", (0.72, 0.47, 0.12), roughness=0.3, metallic=0.7)
        for index in range(5):
            x = (index % 3 - 1) * 0.17
            y = (index // 3) * 0.14 - 0.05
            common.box("treasure chest", (0.20, 0.17, 0.14), (x, y, 1.24), wood, bevel=0.02)
            common.box("chest latch", (0.04, 0.02, 0.055), (x, y - 0.09, 1.25), gold, bevel=0.008)
