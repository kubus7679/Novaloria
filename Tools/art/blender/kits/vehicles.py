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


def _hull_side_width(stations, x: float, z: float) -> float:
    for left, right in zip(stations, stations[1:], strict=False):
        if left[0] <= x <= right[0]:
            fraction = (x - left[0]) / (right[0] - left[0])
            breadth, keel, deck = (
                left[i] + (right[i] - left[i]) * fraction for i in (1, 2, 3)
            )
            mid = (keel + deck) * 0.52
            if z < mid:
                lower_z = keel + 0.06
                return breadth * (0.72 + 0.28 * (z - lower_z) / (mid - lower_z))
            return breadth * (1.0 - 0.14 * (z - mid) / (deck - mid))
    raise ValueError(f"No hull station for x={x}")


def _lateen_sail(mast_x: float, height: float, width: float, material):
    bm = bmesh.new()
    vertices = [bm.verts.new(point) for point in (
        (mast_x - width, -0.02, 0.72),
        (mast_x + width, -0.02, height),
        (mast_x + width * 0.70, -0.13, 0.72),
    )]
    bm.faces.new(vertices)
    sail = common.from_bmesh("lateen sail", bm, material, smooth=False)
    sail.modifiers.new("Canvas thickness", "SOLIDIFY").thickness = 0.012
    thread = _mat("sail seam", (0.66, 0.60, 0.47), roughness=0.95)
    common.limb("sail stitched seam", (mast_x - width * 0.25, -0.09, 0.75),
                (mast_x + width * 0.65, -0.05, height - 0.17), 0.008, 0.008,
                thread, segments=5, rounded=False)
    return sail


def _square_sail(mast_x: float, z0: float, z1: float, width: float, material, billow: float, torn: bool):
    bm = bmesh.new()
    rows, cols = 8, 8
    grid = []
    for row in range(rows + 1):
        v = row / rows
        row_verts = []
        row_width = width * (1.0 - 0.12 * v)
        for col in range(cols + 1):
            u = col / cols * 2.0 - 1.0
            x = mast_x + billow * math.sin(math.pi * v) * (1.0 - u * u)
            y = u * row_width
            z = z0 + (z1 - z0) * v
            row_verts.append(bm.verts.new((x, y, z)))
        grid.append(row_verts)
    for row in range(rows):
        for col in range(cols):
            if torn and ((row <= 1 and col in {0, 1, 5, 6, 7})
                         or (row == 2 and col in {0, 7}) or (row in {3, 4} and col == 5)):
                continue
            bm.faces.new((grid[row][col], grid[row][col + 1], grid[row + 1][col + 1], grid[row + 1][col]))
    obj = common.from_bmesh("square sail", bm, material)
    solidify = obj.modifiers.new("Canvas thickness", "SOLIDIFY")
    solidify.thickness = 0.012
    thread = _mat("sail seam", (0.66, 0.60, 0.47), roughness=0.95)
    for offset in (-0.45, 0.45):
        common.limb("sail stitched seam",
                    (mast_x + billow * 0.75, offset * width, z0 + 0.03),
                    (mast_x + billow * 0.75, offset * width * 0.88, z1 - 0.03),
                    0.008, 0.008, thread, segments=5, rounded=False)
    return obj


def _wheel(x, y, z, radius, wood, iron, broken=False):
    bm = bmesh.new()
    segments = 28
    rings = []
    for r, depth in ((radius, -0.035), (radius, 0.035),
                     (radius * 0.82, -0.035), (radius * 0.82, 0.035)):
        rings.append([bm.verts.new((x + math.cos(i * math.tau / segments) * r,
                                    y + depth,
                                    z + math.sin(i * math.tau / segments) * r))
                      for i in range(segments)])
    for i in range(segments):
        if broken and 1 <= i <= 11:
            continue
        j = (i + 1) % segments
        for a, b in ((0, 1), (2, 0), (1, 3), (3, 2)):
            bm.faces.new((rings[a][i], rings[a][j], rings[b][j], rings[b][i]))
    common.from_bmesh("wooden wheel rim", bm, wood, smooth=False)
    common.cylinder("wheel hub", radius * 0.24, 0.13, (x, y, z), iron, segments=14,
                    rotation=(math.pi / 2, 0.0, 0.0))
    for spoke in range(8):
        if broken and spoke in (0, 1, 2, 3):
            continue
        angle = spoke * math.tau / 8
        end = (x + math.cos(angle) * radius * 0.86, y, z + math.sin(angle) * radius * 0.86)
        common.limb("wheel spoke", (x, y, z), end, radius * 0.065, radius * 0.05, wood,
                    segments=6, rounded=False)
    if broken:
        common.limb("broken wheel spoke", (x, y - 0.04, z), (x + radius * 0.32, y - 0.04, z + radius * 0.28),
                    radius * 0.07, radius * 0.025, wood, segments=6, rounded=False)
        common.limb("fallen wheel fragment", (x + radius * 1.10, y - 0.05, 0.04),
                    (x + radius * 1.95, y - 0.10, 0.11), radius * 0.09, radius * 0.045,
                    wood, segments=6, rounded=False)
        common.limb("splintered wheel fragment", (x + radius * 1.50, y - 0.09, 0.08),
                    (x + radius * 1.78, y - 0.09, 0.18), radius * 0.045, 0.0,
                    wood, segments=5, rounded=False)


def _treasure_chest() -> None:
    wood = _mat("treasure chest oak", (0.52, 0.29, 0.12), roughness=0.78, bands=14.0, bump=0.1)
    brass = _mat("treasure brass", (0.89, 0.64, 0.20), roughness=0.3, metallic=0.65)
    dark = _mat("treasure keyhole", (0.13, 0.10, 0.07), roughness=0.5)
    common.box("treasure chest", (0.74, 0.44, 0.50), (0.0, 0.0, 0.98), wood, bevel=0.025)
    radius, base_z, steps = 0.22, 1.23, 12
    bm = bmesh.new()
    ends = []
    for x in (-0.37, 0.37):
        ends.append([
            bm.verts.new((x, -radius * math.cos(math.pi * i / steps),
                          base_z + radius * math.sin(math.pi * i / steps)))
            for i in range(steps + 1)
        ])
    for i in range(steps):
        bm.faces.new((ends[0][i], ends[1][i], ends[1][i + 1], ends[0][i + 1]))
    bm.faces.new(tuple(reversed(ends[0])))
    bm.faces.new(tuple(ends[1]))
    common.from_bmesh("arched treasure lid", bm, wood, smooth=False)
    for x in (-0.25, 0.25):
        common.box("chest front band", (0.06, 0.025, 0.48), (x, -0.23, 0.98), brass, bevel=0.008)
        for i in range(steps):
            angles = (math.pi * i / steps, math.pi * (i + 1) / steps)
            points = [(x, -0.23 * math.cos(a), base_z + 0.23 * math.sin(a)) for a in angles]
            common.limb("chest lid band", *points, 0.028, 0.028, brass, segments=6, rounded=False)
    common.box("chest lock", (0.13, 0.035, 0.17), (0.0, -0.25, 1.18), brass, bevel=0.015)
    common.box("chest keyhole", (0.035, 0.015, 0.07), (0.0, -0.275, 1.18), dark, bevel=0.006)


def _artillery(damaged: bool, wood, dark) -> None:
    iron = _mat("cannon bronze", (0.25, 0.27, 0.25), roughness=0.36, metallic=0.7)
    common.box("gun carriage", (0.78, 0.28, 0.16), (0.05, 0.0, 0.43), wood, bevel=0.025)
    common.limb("gun carriage trail", (0.28, 0.0, 0.43), (0.80, 0.0, 0.10),
                0.09, 0.055, wood, segments=8)
    common.limb("artillery axle", (0.05, -0.48, 0.31), (0.05, 0.48, 0.31),
                0.05, 0.05, dark, segments=10)
    for side in (-1, 1):
        _wheel(0.05, side * 0.39, 0.31, 0.30, wood, dark, broken=damaged and side == -1)
    common.limb("cannon barrel", (0.30, 0.0, 0.61), (-0.62, 0.0, 0.68),
                0.15, 0.105, iron, segments=18)
    common.cylinder("cannon muzzle", 0.13, 0.06, (-0.64, 0.0, 0.68), iron, segments=18,
                    rotation=(0.0, math.pi / 2, 0.0))
    common.cylinder("cannon bore", 0.065, 0.012, (-0.675, 0.0, 0.68), dark, segments=16,
                    rotation=(0.0, math.pi / 2, 0.0))
    for x in (0.24, 0.43):
        common.sphere("cannon ball", 0.09, (x, -0.24, 0.10), dark, subdivisions=2)
    if damaged:
        exposed = _mat("exposed damaged iron", (0.62, 0.57, 0.48), roughness=0.65, metallic=0.3)
        common.limb("broken carriage", (0.36, -0.28, 0.34), (0.62, -0.44, 0.10),
                    0.06, 0.035, wood, segments=7)
        common.limb("cannon crack", (-0.24, -0.12, 0.63), (-0.02, -0.12, 0.72),
                    0.018, 0.01, exposed, segments=5)


def build_ship(job: dict, view, rng) -> None:
    ship_type = job["params"].get("type", "caravel")
    ghost = ship_type == "flyingDutchman"
    oak_color = {
        "flyingDutchman": (0.20, 0.25, 0.22),
        "galleon": (0.33, 0.16, 0.07),
        "merchantman": (0.38, 0.22, 0.10),
        "frigate": (0.20, 0.25, 0.29),
        "manOWar": (0.16, 0.16, 0.15),
        "privateer": (0.16, 0.11, 0.08),
    }.get(ship_type, (0.25, 0.12, 0.055))
    oak = _mat("hull oak", oak_color, roughness=0.72, bands=11.0, bump=0.18)
    dark = _mat("keel timber", (0.13, 0.075, 0.04), roughness=0.8, bands=8.0)
    deck = _mat("weathered deck", (0.59, 0.39, 0.20), roughness=0.84, bands=22.0, bump=0.12)
    sail_color = {
        "flyingDutchman": (0.47, 0.62, 0.50),
        "manOWar": (0.81, 0.78, 0.66),
        "merchantman": (0.78, 0.70, 0.52),
        "privateer": (0.42, 0.39, 0.35),
    }.get(ship_type, (0.90, 0.82, 0.64))
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
    breadth = 1.12 if ship_type == "merchantman" else 0.86 if ship_type == "privateer" else 1.0
    stations = [(x, width * breadth, keel, deck_height) for x, width, keel, deck_height in stations]
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
    stern_height = {
        "caravel": 0.29,
        "frigate": 0.27,
        "galleon": 0.64,
        "manOWar": 0.40,
        "merchantman": 0.30,
        "privateer": 0.22,
    }.get(ship_type, 0.40)
    common.box("stern castle", (0.30, 0.43, stern_height), (0.61, 0.0, 0.63 + stern_height / 2),
               oak, bevel=0.035)
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
    if ship_type in {"frigate", "galleon", "manOWar", "merchantman"}:
        stripe_color = {
            "frigate": (0.28, 0.39, 0.48),
            "galleon": (0.64, 0.43, 0.19),
            "manOWar": (0.78, 0.68, 0.48),
            "merchantman": (0.61, 0.51, 0.24),
        }[ship_type]
        stripe = _mat("ship identification stripe", stripe_color, roughness=0.82)
        common.limb("ship identification stripe", (-0.72, -0.35, 0.51), (0.63, -0.32, 0.58),
                    0.045, 0.045, stripe, segments=8, rounded=False)
    mast_data = {
        "caravel": [(-0.40, 1.78, 0.42), (0.26, 1.96, 0.38)],
        "privateer": [(-0.42, 1.80, 0.40), (0.20, 2.04, 0.44)],
        "galleon": [(-0.59, 1.72, 0.32), (-0.20, 1.98, 0.38),
                    (0.20, 2.13, 0.42), (0.55, 1.65, 0.27)],
        "frigate": [(-0.54, 1.90, 0.38), (0.03, 2.20, 0.47), (0.55, 1.80, 0.31)],
        "manOWar": [(-0.54, 1.97, 0.43), (0.03, 2.30, 0.51), (0.53, 1.95, 0.37)],
        "merchantman": [(-0.52, 1.72, 0.36), (0.03, 2.05, 0.45), (0.53, 1.65, 0.30)],
    }.get(ship_type, [(-0.54, 1.72, 0.38), (0.03, 2.15, 0.48), (0.55, 1.62, 0.32)])
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
        if ship_type == "caravel" or (ship_type == "galleon" and mast_index >= 2):
            common.limb(
                "lateen yard",
                (x - sail_width, -0.02, 0.72),
                (x + sail_width, -0.02, height),
                0.022,
                0.018,
                dark,
                segments=10,
            )
            _lateen_sail(x, height, sail_width, canvas)
        else:
            for level, factor in ((0.69, 0.92), (1.13, 0.65), (1.53, 0.42)):
                yard_z = level + 0.59
                if yard_z > height - 0.02:
                    continue
                width = sail_width * factor
                common.limb(
                    "square yard",
                    (x, -width, yard_z),
                    (x, width, yard_z),
                    0.022,
                    0.022,
                    dark,
                    segments=10,
                )
                _square_sail(x, yard_z - 0.34, yard_z, width, canvas, rng.uniform(0.05, 0.09), ghost)
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
    main_x, main_height, _ = mast_data[1]
    common.limb("pennant spar", (main_x, 0.0, main_height), (main_x + 0.43, 0.0, main_height),
                0.014, 0.01, dark, segments=7)
    common.limb(
        "pennant",
        (main_x + 0.41, -0.01, main_height - 0.01),
        (main_x + 0.64, -0.01, main_height - 0.09),
        0.025,
        0.0,
        _mat("red pennant", (0.58, 0.09, 0.055)),
        segments=4,
        rounded=False,
    )
    if ship_type in {"frigate", "manOWar", "privateer"}:
        gunmetal = _mat("ship cannon", (0.19, 0.18, 0.16), metallic=0.45, roughness=0.42)
        gunport_frame = _mat("gun port trim", (0.72, 0.57, 0.32), roughness=0.8)
        gunport_opening = _mat("gun port opening", (0.055, 0.045, 0.035), roughness=0.85)
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
                rows = (("gun port", 0.52), ("lower gun port", 0.35)) if ship_type == "manOWar" else (
                    ("gun port", 0.52),
                )
                for name, z in rows:
                    width = _hull_side_width(stations, x, z)
                    common.box(f"{name} frame", (0.12, 0.025, 0.10), (x, side * (width + 0.025), z),
                               gunport_frame, bevel=0.008)
                    common.box(name, (0.075, 0.015, 0.06), (x, side * (width + 0.045), z),
                               gunport_opening, bevel=0.005)
    if ship_type == "merchantman":
        for x in (-0.28, 0.22):
            common.box("merchant cargo crate", (0.20, 0.19, 0.18), (x, -0.16, 0.70), deck, bevel=0.02)
    if ship_type == "galleon":
        common.box("galleon stern gallery", (0.27, 0.48, 0.16), (0.68, 0.0, 1.23), deck, bevel=0.02)
        for z in (0.92, 1.08):
            common.box("galleon gallery window", (0.17, 0.025, 0.065), (0.62, -0.23, z),
                       brass, bevel=0.01)
    if ghost:
        for side in (-1, 1):
            common.limb(
                "ghost pennant",
                (main_x, side * 0.02, main_height - 0.05),
                (main_x + 0.30, side * 0.02, main_height - 0.19),
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
    if wagon_type in {"artillery", "damagedArtillery"}:
        _artillery(wagon_type == "damagedArtillery", wood, dark)
        return
    canvas = _mat("wagon canvas", (0.84, 0.75, 0.58), roughness=0.92, variation=0.1, bump=0.06)
    common.box("wagon bed", (0.90, 0.57, 0.12), (0.0, 0.0, 0.64), wood, bevel=0.035)
    common.box("front board", (0.08, 0.59, 0.42), (-0.40, 0.0, 0.80), wood, bevel=0.02)
    common.box("rear board", (0.08, 0.59, 0.42), (0.40, 0.0, 0.80), wood, bevel=0.02)
    common.box("side rail", (0.82, 0.055, 0.25), (0.0, -0.25, 0.78), wood, bevel=0.025)
    common.box("side rail", (0.82, 0.055, 0.25), (0.0, 0.25, 0.78), wood, bevel=0.025)
    common.limb("axle", (-0.02, -0.56, 0.45), (-0.02, 0.56, 0.45), 0.055, 0.055, dark, segments=10)
    for x in (-0.29, 0.29):
        for side in (-1, 1):
            _wheel(x, side * 0.48, 0.46, 0.35, wood, dark)
    if wagon_type == "treasureTrain":
        _treasure_chest()
        common.limb("wagon tongue", (-0.43, 0.0, 0.57), (-0.98, 0.0, 0.43),
                    0.045, 0.03, wood, segments=10)
        return
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
