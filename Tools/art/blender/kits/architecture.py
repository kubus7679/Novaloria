"""Colonial architecture and settlement vignettes."""

from __future__ import annotations

import math

import bmesh

from . import common


def _mat(name, color, **kwargs):
    kwargs.setdefault("variation", 0.12)
    return common.material(name, color, **kwargs)


def _gable_roof(name, center, width, depth, eave, peak, mat):
    x, y, z = center
    bm = bmesh.new()
    coords = [
        (-width / 2, -depth / 2, eave),
        (0, -depth / 2, peak),
        (width / 2, -depth / 2, eave),
        (-width / 2, depth / 2, eave),
        (0, depth / 2, peak),
        (width / 2, depth / 2, eave),
    ]
    vertices = [bm.verts.new((x + px, y + py, z + pz)) for px, py, pz in coords]
    bm.faces.new((vertices[0], vertices[1], vertices[4], vertices[3]))
    bm.faces.new((vertices[1], vertices[2], vertices[5], vertices[4]))
    bm.faces.new((vertices[0], vertices[2], vertices[5], vertices[3]))
    return common.from_bmesh(name, bm, mat, smooth=False)


def _house(name, location, scale, rng, style="clapboard", colors=None, chimney=True):
    x, y, z = location
    width, depth, wall_h = scale
    colors = colors or {}
    wall_color = colors.get("wall", (0.78, 0.70, 0.53))
    wall = _mat(
        f"{name} walls",
        wall_color,
        roughness=0.88,
        variation=0.1,
        scale=18.0,
        bands=26.0 if style == "clapboard" else 0.0,
    )
    roof = _mat(
        f"{name} roof",
        colors.get("roof", (0.25, 0.16, 0.10)),
        roughness=0.86,
        variation=0.2,
        scale=20.0,
        bump=0.10,
    )
    wood = _mat(
        f"{name} trim", colors.get("trim", (0.30, 0.18, 0.09)), roughness=0.78, variation=0.15, bands=14.0
    )
    stone = _mat(f"{name} stone", (0.42, 0.39, 0.32), roughness=0.92, variation=0.2)
    common.box(
        f"{name} foundation", (width * 1.06, depth * 1.08, 0.11), (x, y, z + 0.055), stone, bevel=0.025
    )
    common.box(f"{name} walls", (width, depth, wall_h), (x, y, z + 0.11 + wall_h / 2), wall, bevel=0.015)
    eave = z + 0.11 + wall_h
    peak = eave + width * rng.uniform(0.35, 0.48)
    _gable_roof(f"{name} roof", (x, y, 0.0), width * 1.16, depth * 1.16, eave, peak, roof)
    # Fascia and corner posts keep the small silhouette legible.
    for side in (-1, 1):
        common.box(
            f"{name} corner post",
            (0.035, depth * 1.04, wall_h),
            (x + side * width * 0.47, y, z + 0.11 + wall_h / 2),
            wood,
        )
    front_y = y - depth * 0.51
    common.box(
        f"{name} door",
        (width * 0.22, 0.035, wall_h * 0.62),
        (x - width * 0.19, front_y, z + 0.11 + wall_h * 0.31),
        wood,
        bevel=0.012,
    )
    common.sphere(
        f"{name} latch",
        0.018,
        (x - width * 0.14, front_y - 0.022, z + 0.11 + wall_h * 0.33),
        _mat("door latch", (0.66, 0.47, 0.18), metallic=0.45),
        subdivisions=2,
    )
    for side in (-1, 1):
        wx = x + side * width * 0.22
        common.box(
            f"{name} window frame",
            (width * 0.19, 0.045, wall_h * 0.27),
            (wx, front_y - 0.006, z + 0.11 + wall_h * 0.64),
            wood,
            bevel=0.012,
        )
        common.box(
            f"{name} window glass",
            (width * 0.14, 0.012, wall_h * 0.21),
            (wx, front_y - 0.032, z + 0.11 + wall_h * 0.64),
            _mat("old glass", (0.25, 0.37, 0.40), roughness=0.28, metallic=0.1),
        )
        common.box(
            f"{name} window mullion",
            (0.015, 0.014, wall_h * 0.22),
            (wx, front_y - 0.042, z + 0.11 + wall_h * 0.64),
            wood,
        )
    if chimney:
        cx = x + width * 0.29
        common.box(
            f"{name} chimney",
            (width * 0.13, depth * 0.16, wall_h * 0.72),
            (cx, y + depth * 0.20, eave + wall_h * 0.48),
            _mat("chimney brick", (0.44, 0.20, 0.12), roughness=0.9, variation=0.2),
        )
        common.box(
            f"{name} chimney cap",
            (width * 0.18, depth * 0.21, 0.04),
            (cx, y + depth * 0.20, eave + wall_h * 0.85),
            stone,
        )


def _flag(x, y, z, pole_mat, cloth_mat):
    common.limb("flagstaff", (x, y, z), (x, y, z + 0.52), 0.018, 0.012, pole_mat, segments=8)
    common.limb(
        "flag",
        (x, y - 0.015, z + 0.46),
        (x + 0.22, y - 0.015, z + 0.43),
        0.06,
        0.0,
        cloth_mat,
        segments=5,
        rounded=False,
    )


def build_building(job: dict, view, rng) -> None:
    kind = job["params"]["type"]
    grass = _mat("building grounds", (0.30, 0.39, 0.17), roughness=0.95, variation=0.24, scale=13.0)
    common.box("ground patch", (1.80, 1.12, 0.06), (0.0, 0.0, 0.02), grass, bevel=0.16)
    if kind == "townHall":
        colors = {"wall": (0.82, 0.79, 0.67), "roof": (0.20, 0.16, 0.12), "trim": (0.31, 0.23, 0.14)}
        _house("town hall", (0.0, 0.04, 0.05), (0.90, 0.66, 0.78), rng, colors=colors, chimney=False)
        _house("town hall wing", (0.0, 0.04, 0.81), (0.68, 0.63, 0.50), rng, colors=colors, chimney=False)
        _gable_roof(
            "upper roof",
            (0.0, 0.04, 0.0),
            0.80,
            0.75,
            1.42,
            1.76,
            _mat("upper roof slate", (0.18, 0.15, 0.12), roughness=0.84),
        )
        common.box(
            "cupola base",
            (0.25, 0.25, 0.30),
            (0.0, 0.05, 1.80),
            colors_mat := _mat("cupola", (0.78, 0.74, 0.62)),
        )
        common.cylinder(
            "cupola roof",
            0.19,
            0.20,
            (0.0, 0.05, 2.05),
            _mat("cupola copper", (0.24, 0.31, 0.23)),
            radius2=0.0,
            segments=12,
        )
        _flag(
            0.0, 0.04, 2.14, _mat("flag pole", (0.26, 0.19, 0.10)), _mat("colonial flag", (0.62, 0.12, 0.07))
        )
        for side in (-1, 1):
            common.box("porch post", (0.045, 0.045, 0.48), (side * 0.32, -0.42, 0.32), colors_mat)
        common.box(
            "porch canopy", (0.79, 0.28, 0.06), (0.0, -0.42, 0.58), _mat("porch roof", (0.25, 0.17, 0.12))
        )
    elif kind == "carpenterHouse":
        log = _mat("hewn logs", (0.35, 0.21, 0.105), roughness=0.86, bands=12.0, bump=0.12)
        _house(
            "carpenter house",
            (-0.25, 0.05, 0.05),
            (0.98, 0.72, 0.66),
            rng,
            style="logs",
            colors={"wall": (0.37, 0.25, 0.13), "roof": (0.32, 0.20, 0.11), "trim": (0.23, 0.14, 0.07)},
        )
        for row in range(3):
            common.box("lumber stack", (0.46, 0.16, 0.10), (0.48, 0.14, 0.16 + row * 0.11), log, bevel=0.015)
        common.box("sawhorse top", (0.43, 0.08, 0.05), (0.49, -0.06, 0.60), log)
        for side in (-1, 1):
            common.limb(
                "sawhorse leg",
                (0.49, -0.06, 0.29),
                (0.49 + side * 0.13, -0.06, 0.57),
                0.025,
                0.025,
                log,
                segments=7,
            )
        # A small awning marks the open woodworking shed.
        common.box(
            "workshop awning",
            (0.44, 0.42, 0.045),
            (0.48, -0.32, 0.72),
            log,
            rotation=(math.radians(-9), 0.0, 0.0),
        )
    elif kind == "church":
        white = {"wall": (0.85, 0.82, 0.70), "roof": (0.25, 0.18, 0.12), "trim": (0.36, 0.25, 0.14)}
        _house("chapel nave", (0.12, 0.10, 0.05), (0.92, 0.78, 0.77), rng, colors=white, chimney=False)
        common.box(
            "church tower",
            (0.36, 0.40, 0.94),
            (-0.32, -0.08, 0.58),
            _mat("tower plaster", white["wall"]),
            bevel=0.015,
        )
        common.box(
            "bell opening", (0.12, 0.02, 0.18), (-0.32, -0.296, 0.93), _mat("bell shadow", (0.16, 0.13, 0.10))
        )
        common.cylinder(
            "tower spire",
            0.25,
            0.48,
            (-0.32, -0.08, 1.30),
            _mat("slate spire", (0.20, 0.17, 0.13)),
            radius2=0.0,
            segments=12,
        )
        common.limb(
            "church cross",
            (-0.32, -0.08, 1.48),
            (-0.32, -0.08, 1.78),
            0.018,
            0.015,
            _mat("church brass", (0.62, 0.48, 0.20), metallic=0.55),
            segments=8,
        )
        common.limb(
            "church crossbar",
            (-0.41, -0.08, 1.67),
            (-0.23, -0.08, 1.67),
            0.015,
            0.015,
            _mat("church brass", (0.62, 0.48, 0.20), metallic=0.55),
            segments=8,
        )
    else:
        token = kind.lower()
        fortified = any(part in token for part in ("fort", "stockade"))
        school = any(part in token for part in ("school", "college", "university"))
        church = any(part in token for part in ("chapel", "cathedral"))
        industrial = any(part in token for part in ("mill", "works", "factory", "smith", "distill", "press"))
        colors = (
            {"wall": (0.73, 0.72, 0.62), "roof": (0.23, 0.20, 0.15), "trim": (0.34, 0.27, 0.16)}
            if school or church
            else {"wall": (0.47, 0.32, 0.18), "roof": (0.29, 0.18, 0.10), "trim": (0.24, 0.14, 0.07)}
            if industrial
            else {"wall": (0.72, 0.58, 0.39), "roof": (0.28, 0.18, 0.11), "trim": (0.34, 0.22, 0.11)}
        )
        width = 0.94 if any(part in token for part in ("warehouse", "depot", "customHouse".lower())) else 0.72
        height = 0.82 if school or industrial else 0.65
        style = "logs" if industrial or "warehouse" in token else "clapboard"
        _house(kind, (0.0, 0.02, 0.05), (width, 0.67, height), rng, style=style,
               colors=colors, chimney=industrial)
        if fortified:
            stone = _mat("fortification stone", (0.43, 0.41, 0.35), roughness=0.93, variation=0.18)
            common.box("fortified base", (1.14, 0.88, 0.18), (0.0, 0.02, 0.12), stone, bevel=0.04)
            for x in (-0.56, 0.56):
                common.box("fort bastion", (0.25, 0.26, 0.90), (x, 0.03, 0.62), stone, bevel=0.03)
                common.cylinder("bastion cap", 0.20, 0.20, (x, 0.03, 1.16),
                                _mat("fort roof", (0.22, 0.17, 0.12)), radius2=0.0, segments=8)
        if school:
            for row in range(2):
                common.box("school wing", (0.20, 0.46, 0.30), (-0.49 + row * 0.98, 0.03, 0.24),
                           _mat("school plaster", colors["wall"]), bevel=0.025)
            common.cylinder("school cupola", 0.15, 0.36, (0.0, 0.02, 1.05),
                            _mat("school cupola", (0.32, 0.27, 0.18)), radius2=0.11, segments=12)
        if church:
            common.cylinder("church bell tower", 0.17, 0.58, (-0.30, -0.08, 1.05),
                            _mat("church tower", (0.76, 0.72, 0.61)), radius2=0.15, segments=12)
            common.cylinder("church spire", 0.23, 0.43, (-0.30, -0.08, 1.52),
                            _mat("church roof", colors["roof"]), radius2=0.0, segments=10)
        if industrial:
            for x in (0.20, 0.32):
                common.box("factory stack", (0.12, 0.13, 0.60), (x, 0.18, 1.25),
                           _mat("smoke stained brick", (0.40, 0.24, 0.16)), bevel=0.015)
            common.sphere("smoke", 0.16, (0.30, 0.18, 1.70),
                          _mat("chimney smoke", (0.55, 0.53, 0.49), roughness=0.98), scale=(1.1, 0.9, 0.8))
        if any(part in token for part in ("dock", "shipyard")):
            for row in range(4):
                common.box("pier plank", (0.20, 0.82, 0.06), (-0.35 + row * 0.23, -0.72, 0.10),
                           _mat("pier wood", (0.43, 0.29, 0.15), bands=12.0))
            for x in (-0.48, 0.48):
                common.limb("pier pile", (x, -0.95, 0.0), (x, -0.95, 0.40), 0.05, 0.04,
                            _mat("pier pile", (0.29, 0.18, 0.09)))
        if "warehouse" in token or "depot" in token:
            for row in range(2):
                for column in range(2):
                    common.box("stored crate", (0.24, 0.20, 0.22),
                               (0.35 + column * 0.25, -0.38, 0.17 + row * 0.23),
                               _mat("crate wood", (0.48, 0.32, 0.16)), bevel=0.02)


def _settlement_tree(x, y, scale, rng):
    bark = _mat("settlement tree bark", (0.30, 0.18, 0.08))
    leaves = [
        _mat("settlement foliage", color, roughness=0.87, random_tint=0.3)
        for color in ((0.15, 0.27, 0.08), (0.23, 0.34, 0.09), (0.30, 0.37, 0.11))
    ]
    common.limb("settlement trunk", (x, y, 0.0), (x, y, scale * 0.8), scale * 0.08, scale * 0.04, bark)
    for _ in range(6):
        angle = rng.random() * math.tau
        radius = rng.uniform(0.05, 0.28) * scale
        common.sphere(
            "settlement canopy",
            scale * rng.uniform(0.22, 0.36),
            (x + math.cos(angle) * radius, y + math.sin(angle) * radius, scale * rng.uniform(0.72, 1.18)),
            rng.choice(leaves),
            subdivisions=2,
            jitter=0.025,
            seed=rng.randrange(50000),
        )


def _field(x, y, width, height, rng):
    soil = _mat("furrow soil", (0.40, 0.30, 0.15), roughness=0.95)
    crop = _mat("young crops", (0.40, 0.48, 0.14), roughness=0.88)
    common.box("cultivated plot", (width, height, 0.035), (x, y, 0.025), soil, bevel=0.025)
    for row in range(5):
        yy = y - height * 0.38 + row * height * 0.19
        common.limb(
            "crop furrow",
            (x - width * 0.44, yy, 0.055),
            (x + width * 0.44, yy, 0.055),
            0.012,
            0.012,
            crop,
            segments=5,
            rounded=False,
        )


def build_settlement(job: dict, view, rng) -> None:
    kind = job["params"].get("type", job["params"].get("size", "small"))
    size_name = job["params"].get("size", kind.split("_", 1)[0])
    medium = size_name in {"medium", "large"}
    large = size_name == "large"
    native = kind in {"indian_camp", "indian_village", "aztec_city", "inca_city"}
    if native:
        earth = _mat("native earth", (0.48, 0.34, 0.20), roughness=0.94)
        thatch = _mat("woven thatch", (0.63, 0.45, 0.23), roughness=0.9)
        common.box("native settlement earth", (1.75, 1.05, 0.05), (0.0, 0.0, 0.02), earth, bevel=0.12)
        if kind in {"aztec_city", "inca_city"}:
            for level in range(4):
                width = 1.12 - level * 0.22
                common.box("stepped temple", (width, width * 0.72, 0.19),
                           (0.0, 0.05, 0.12 + level * 0.19),
                           _mat("temple stone", (0.55, 0.45, 0.31)), bevel=0.025)
            common.box("temple shrine", (0.31, 0.25, 0.22), (0.0, 0.05, 0.97), thatch, bevel=0.02)
            count = 4
        else:
            count = 2 if kind == "indian_camp" else 5
            for index in range(count):
                x = (index - (count - 1) / 2) * 0.35
                y = 0.12 if index % 2 else -0.20
                common.cylinder("native lodge", 0.29, 0.66, (x, y, 0.36), thatch,
                                radius2=0.0, segments=9)
                common.cylinder("lodge entrance", 0.09, 0.20, (x, y - 0.22, 0.15), earth,
                                segments=10)
        for _ in range(3):
            _settlement_tree(rng.uniform(-0.74, 0.74), rng.uniform(-0.42, 0.42), rng.uniform(0.35, 0.50), rng)
        return
    grass = _mat("settlement meadow", (0.31, 0.41, 0.18), roughness=0.94, variation=0.2, scale=12)
    common.box("settlement ground", (2.05, 1.30, 0.045), (0.0, 0.0, 0.015), grass, bevel=0.20)
    colors = {"wall": (0.70, 0.54, 0.33), "roof": (0.27, 0.17, 0.10), "trim": (0.31, 0.19, 0.09)}
    houses = [(-0.49, 0.16), (0.17, 0.23), (0.58, -0.12)]
    if medium:
        houses.extend([(-0.57, -0.25), (0.12, -0.31)])
    if large:
        houses.extend([(-0.77, 0.10), (0.50, -0.34), (0.77, 0.20)])
    for index, (x, y) in enumerate(houses):
        size = (0.38, 0.30, 0.38) if index else (0.44, 0.35, 0.46)
        _house(
            f"settlement house {index}",
            (x, y, 0.05),
            size,
            rng,
            colors=colors if rng.random() > 0.3 else None,
            chimney=rng.random() > 0.4,
        )
    if medium:
        # A small meeting-house tower anchors the larger settlement silhouette.
        common.box(
            "meeting house",
            (0.43, 0.35, 0.48),
            (-0.08, 0.06, 0.30),
            _mat("meeting house plaster", (0.76, 0.72, 0.59)),
            bevel=0.02,
        )
        common.cylinder(
            "meeting house tower",
            0.14,
            0.32,
            (-0.08, 0.06, 0.70),
            _mat("meeting house tower", (0.58, 0.47, 0.31)),
            radius2=0.10,
            segments=12,
        )
        _field(0.67, 0.33, 0.46, 0.30, rng)
        _field(-0.62, 0.38, 0.40, 0.28, rng)
    if "stockade" in kind or "fort" in kind:
        palisade = _mat("palisade timber", (0.34, 0.22, 0.11), roughness=0.9)
        for index in range(9):
            x = -0.92 + index * 0.23
            common.limb("palisade", (x, -0.52, 0.02), (x, -0.52, 0.54), 0.045, 0.006, palisade,
                        segments=6, rounded=False)
            common.limb("palisade", (x, 0.52, 0.02), (x, 0.52, 0.54), 0.045, 0.006, palisade,
                        segments=6, rounded=False)
        for side in (-1, 1):
            for index in range(5):
                y = -0.42 + index * 0.21
                common.limb("palisade", (side * 0.92, y, 0.02), (side * 0.92, y, 0.54),
                            0.045, 0.006, palisade, segments=6, rounded=False)
        if "fortress" in kind or "fort" in kind:
            for x in (-0.86, 0.86):
                common.box("settlement bastion", (0.24, 0.25, 0.68), (x, 0.0, 0.37), palisade, bevel=0.03)
    for _ in range(4 if medium else 2):
        _settlement_tree(rng.uniform(-0.82, 0.82), rng.uniform(-0.49, 0.49), rng.uniform(0.4, 0.58), rng)
