"""Goods icons, field bonus and lost-city ruin vignette."""

from __future__ import annotations

import math

import bmesh
from mathutils import Vector

from . import common


def _mat(name, color, **kwargs):
    kwargs.setdefault("variation", 0.1)
    return common.material(name, color, **kwargs)


def _barrel(x, y, z, scale, wood, hoops):
    common.cylinder(
        "barrel staves",
        0.24 * scale,
        0.48 * scale,
        (x, y, z + 0.24 * scale),
        wood,
        radius2=0.20 * scale,
        segments=14,
    )
    for level in (0.08, 0.38):
        common.cylinder(
            "barrel hoop",
            0.245 * scale,
            0.035 * scale,
            (x, y, z + level * scale),
            hoops,
            radius2=0.225 * scale,
            segments=16,
        )
    common.cylinder("barrel lid", 0.20 * scale, 0.025 * scale, (x, y, z + 0.49 * scale), wood, segments=14)
    for stave in range(10):
        angle = math.tau * stave / 10
        common.limb(
            "barrel stave line",
            (x + math.cos(angle) * 0.225 * scale, y + math.sin(angle) * 0.225 * scale, z + 0.11 * scale),
            (x + math.cos(angle) * 0.205 * scale, y + math.sin(angle) * 0.205 * scale, z + 0.40 * scale),
            0.006 * scale,
            0.006 * scale,
            hoops,
            segments=4,
            rounded=False,
        )


def _basket(x, y, z, scale, wicker):
    common.cylinder(
        "basket",
        0.24 * scale,
        0.24 * scale,
        (x, y, z + 0.12 * scale),
        wicker,
        radius2=0.31 * scale,
        segments=18,
    )
    for level in (0.06, 0.12, 0.18):
        common.cylinder(
            "basket weave",
            0.25 * scale + (level / 0.24) * 0.06 * scale,
            0.018 * scale,
            (x, y, z + level * scale),
            _mat("basket weave highlight", (0.67, 0.47, 0.23)),
            radius2=0.27 * scale,
            segments=18,
        )


def _produce(x, y, z, rng, food):
    for _ in range(13):
        angle = rng.random() * math.tau
        radius = rng.uniform(0.03, 0.19)
        size = rng.uniform(0.045, 0.075)
        common.sphere(
            "basket produce",
            size,
            (x + math.cos(angle) * radius, y + math.sin(angle) * radius, z + rng.uniform(0.25, 0.39)),
            rng.choice(food),
            scale=(1.0, 0.85, 0.9),
            subdivisions=2,
            jitter=0.006,
            seed=rng.randrange(50000),
        )


def _tool_blade(name, start, end, width, material):
    start, end = Vector(start), Vector(end)
    side = Vector((-(end - start).z, 0.0, (end - start).x)).normalized() * width / 2
    bm = bmesh.new()
    v = [bm.verts.new(start + side), bm.verts.new(start - side), bm.verts.new(end)]
    bm.faces.new(v)
    obj = common.from_bmesh(name, bm, material, smooth=False)
    modifier = obj.modifiers.new("Forged edge", "SOLIDIFY")
    modifier.thickness = 0.025
    return obj


def _pelt(x, y, z, material, size=1.0, seed=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    common.displace(bm, 0.16, 2.4, seed)
    bmesh.ops.scale(bm, vec=(size * 0.31, size * 0.22, size * 0.11), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(x, y, z + size * 0.11), verts=bm.verts)
    obj = common.from_bmesh("folded fur pelt", bm, material)
    obj.rotation_euler.z = seed * 0.7
    return obj


def _generic_good(kind: str, rng, wood, dark, brass) -> None:
    colors = {
        "bells": (0.72, 0.53, 0.16),
        "cigars": (0.42, 0.20, 0.08),
        "cloth": (0.30, 0.42, 0.62),
        "coats": (0.48, 0.19, 0.12),
        "cotton": (0.86, 0.83, 0.72),
        "crosses": (0.74, 0.61, 0.33),
        "fish": (0.30, 0.48, 0.52),
        "grain": (0.75, 0.55, 0.16),
        "hammers": (0.47, 0.49, 0.48),
        "horses": (0.38, 0.20, 0.10),
        "lumber": (0.42, 0.27, 0.13),
        "meat": (0.55, 0.24, 0.16),
        "ore": (0.38, 0.36, 0.32),
        "silver": (0.72, 0.74, 0.73),
        "sugar": (0.84, 0.79, 0.60),
        "tobacco": (0.34, 0.37, 0.13),
        "tradeGoods": (0.56, 0.34, 0.18),
    }
    color = colors.get(kind, (0.48, 0.34, 0.18))
    item = _mat(
        f"{kind} material", color, roughness=0.78, metallic=0.18 if kind in {"bells", "silver"} else 0
    )
    if kind == "bells":
        common.cylinder("bell body", 0.20, 0.28, (0.0, 0.0, 0.21), item, radius2=0.08, segments=18)
        common.cylinder("bell crown", 0.08, 0.10, (0.0, 0.0, 0.40), brass, segments=14)
        common.limb("bell handle", (-0.12, 0.0, 0.46), (0.12, 0.0, 0.46), 0.025, 0.025, brass)
        common.sphere("bell clapper", 0.045, (0.0, -0.02, 0.05), dark, subdivisions=2)
    elif kind == "crosses":
        for index in range(3):
            x = (index - 1) * 0.16
            common.limb("wooden cross", (x, 0.0, 0.05), (x, 0.0, 0.68), 0.045, 0.04, item)
            common.limb("cross bar", (x - 0.14, 0.0, 0.45), (x + 0.14, 0.0, 0.45), 0.04, 0.04, item)
    elif kind == "cigars":
        for index in range(5):
            x = (index % 2 - 0.5) * 0.17
            z = 0.12 + (index // 2) * 0.12
            common.cylinder(
                "rolled cigar",
                0.055,
                0.47,
                (x, 0.0, z),
                item,
                radius2=0.042,
                segments=12,
                rotation=(0.0, math.radians(72), math.radians((index - 2) * 8)),
            )
            common.cylinder(
                "cigar band",
                0.057,
                0.04,
                (x, -0.01, z + 0.12),
                brass,
                segments=12,
                rotation=(0.0, math.radians(72), math.radians((index - 2) * 8)),
            )
    elif kind == "lumber":
        for layer in range(3):
            for index in range(4):
                y = (index % 2 - 0.5) * 0.20
                x = (index // 2 - 0.5) * 0.16
                z = 0.10 + layer * 0.15
                common.cylinder(
                    "cut lumber",
                    0.085,
                    0.62,
                    (x, y, z),
                    item,
                    segments=12,
                    rotation=(0.0, math.radians(90), math.radians((index + layer) % 2 * 90)),
                )
    elif kind in {"ore", "silver"}:
        metal = _mat("mineral shine", color, roughness=0.26, metallic=0.78)
        for index in range(8):
            angle = index * math.tau / 8
            size = rng.uniform(0.10, 0.18)
            common.sphere(
                "ore chunk",
                size,
                (math.cos(angle) * 0.16, math.sin(angle) * 0.12, 0.08 + (index % 3) * 0.09),
                metal,
                scale=(1.0, 0.8, 1.2),
                subdivisions=1,
                jitter=0.025,
                seed=rng.randrange(50000),
            )
    elif kind == "fish":
        for index in range(3):
            z = 0.18 + index * 0.16
            common.sphere(
                "market fish",
                0.17,
                ((index - 1) * 0.12, 0.0, z),
                item,
                scale=(1.4, 0.55, 0.7),
                subdivisions=2,
                seed=index,
            )
            common.limb(
                "fish tail",
                ((index - 1) * 0.12 + 0.20, 0.0, z),
                ((index - 1) * 0.12 + 0.36, 0.0, z + 0.08),
                0.06,
                0.0,
                item,
                segments=5,
                rounded=False,
            )
    elif kind in {"cotton", "sugar", "tobacco", "grain"}:
        for index in range(8):
            x = (index % 4 - 1.5) * 0.13
            y = (index // 4 - 0.5) * 0.13
            height = rng.uniform(0.35, 0.62)
            common.limb("crop stalk", (x, y, 0.04), (x, y, height), 0.018, 0.012, item, segments=6)
            if kind == "cotton":
                common.sphere(
                    "cotton boll",
                    0.075,
                    (x, y, height),
                    _mat("cotton", (0.88, 0.85, 0.75)),
                    scale=(1.0, 0.9, 0.85),
                    subdivisions=2,
                    jitter=0.012,
                    seed=index,
                )
            else:
                for side in (-1, 1):
                    common.sphere(
                        "crop leaf",
                        0.06,
                        (x + side * 0.06, y, height * 0.55),
                        item,
                        scale=(1.1, 0.7, 0.45),
                        subdivisions=2,
                    )
    elif kind == "horses":
        hide = item
        for x in (-0.20, 0.0, 0.20):
            common.sphere("horse icon", 0.16, (x, 0.0, 0.34), hide, scale=(1.15, 0.6, 1.0), subdivisions=2)
            common.limb("horse neck", (x - 0.08, 0.0, 0.37), (x - 0.12, 0.0, 0.61), 0.075, 0.045, hide)
            common.limb("horse leg", (x - 0.04, -0.03, 0.28), (x - 0.08, -0.03, 0.06), 0.035, 0.02, dark)
    else:
        common.box("goods crate", (0.50, 0.42, 0.42), (0.0, 0.0, 0.23), wood, bevel=0.04)
        common.box("goods bundle", (0.45, 0.37, 0.34), (0.0, -0.02, 0.59), item, bevel=0.08)
        for side in (-1, 1):
            common.limb(
                "bundle rope",
                (side * 0.12, -0.22, 0.42),
                (side * 0.12, -0.22, 0.78),
                0.014,
                0.014,
                brass,
                segments=6,
            )


def build_goods(job: dict, view, rng) -> None:
    kind = job["params"]["type"]
    wood = _mat("stained oak", (0.37, 0.22, 0.11), roughness=0.82, bands=14.0, bump=0.1)
    dark = _mat("iron", (0.16, 0.15, 0.13), roughness=0.38, metallic=0.62)
    wicker = _mat("willow wicker", (0.55, 0.37, 0.17), roughness=0.9, variation=0.12)
    brass = _mat("brass", (0.62, 0.42, 0.15), roughness=0.28, metallic=0.65)
    if kind == "food":
        _basket(0.0, 0.04, 0.0, 1.0, wicker)
        _produce(
            0.0,
            0.04,
            0.0,
            rng,
            [
                _mat("red apples", (0.62, 0.12, 0.055), roughness=0.34),
                _mat("green apples", (0.32, 0.48, 0.10), roughness=0.38),
            ],
        )
        for side in (-1, 1):
            common.limb(
                "corn stalk",
                (side * 0.11, 0.03, 0.24),
                (side * 0.17, 0.02, 0.55),
                0.018,
                0.012,
                _mat("corn husk", (0.55, 0.48, 0.18)),
                segments=7,
            )
            common.sphere(
                "corn cob",
                0.055,
                (side * 0.17, 0.0, 0.46),
                _mat("gold corn", (0.83, 0.62, 0.12)),
                scale=(0.8, 0.8, 1.5),
                subdivisions=2,
            )
    elif kind == "furs":
        fur = [
            _mat("beaver fur", (0.27, 0.15, 0.08), roughness=0.96, variation=0.24),
            _mat("fox fur", (0.55, 0.25, 0.095), roughness=0.93, variation=0.2),
            _mat("silver fur", (0.43, 0.42, 0.37), roughness=0.95, variation=0.18),
        ]
        for index in range(7):
            _pelt(
                (index % 3 - 1) * 0.13,
                (index // 3) * 0.11,
                (index // 3) * 0.09,
                fur[index % len(fur)],
                size=0.9 + 0.12 * (index % 2),
                seed=index + 3,
            )
    elif kind == "rum":
        _barrel(-0.09, 0.02, 0.0, 1.0, wood, dark)
        glass = _mat("dark bottle glass", (0.10, 0.24, 0.19), roughness=0.22, metallic=0.12)
        common.cylinder("rum bottle", 0.085, 0.36, (0.22, -0.07, 0.19), glass, radius2=0.10, segments=14)
        common.cylinder("bottle neck", 0.045, 0.11, (0.22, -0.07, 0.42), glass, segments=12)
        common.cylinder("bottle cork", 0.031, 0.055, (0.22, -0.07, 0.50), wood, segments=10)
        common.box(
            "bottle label", (0.09, 0.015, 0.11), (0.22, -0.164, 0.20), _mat("cream label", (0.84, 0.72, 0.48))
        )
    elif kind == "tools":
        common.box("tool crate", (0.61, 0.44, 0.29), (0.0, 0.02, 0.15), wood, bevel=0.045)
        for x in (-0.19, 0.0, 0.19):
            common.box(
                "crate board",
                (0.04, 0.015, 0.25),
                (x, -0.208, 0.16),
                _mat("crate plank", (0.50, 0.32, 0.15)),
                bevel=0.01,
            )
        common.limb(
            "hammer handle", (-0.19, -0.03, 0.31), (-0.06, -0.03, 0.72), 0.025, 0.025, wood, segments=8
        )
        common.box("hammer head", (0.25, 0.09, 0.11), (-0.06, -0.03, 0.72), dark, bevel=0.025)
        common.limb("saw handle", (0.12, -0.06, 0.31), (0.33, -0.06, 0.42), 0.055, 0.035, wood)
        _tool_blade("saw blade", (0.30, -0.07, 0.43), (0.50, -0.07, 0.89), 0.16, dark)
        for index in range(6):
            z = 0.48 + index * 0.055
            common.sphere(
                "saw tooth",
                0.018,
                (0.35 + index * 0.025, -0.085, z),
                brass,
                scale=(1.0, 0.35, 0.65),
                subdivisions=1,
            )
    elif kind == "muskets":
        _barrel(-0.06, 0.13, 0.02, 0.66, wood, dark)
        for side in (-1, 1):
            x0 = side * 0.24
            common.limb(
                "musket stock", (x0, -0.06, 0.10), (-x0 * 0.6, -0.06, 0.91), 0.042, 0.022, wood, segments=9
            )
            common.limb(
                "musket barrel",
                (-x0 * 0.6, -0.075, 0.66),
                (-x0 * 0.6, -0.075, 1.03),
                0.014,
                0.009,
                dark,
                segments=7,
                rounded=False,
            )
            common.limb(
                "musket trigger guard",
                (x0 * 0.15, -0.09, 0.44),
                (x0 * 0.02, -0.09, 0.54),
                0.009,
                0.009,
                brass,
                segments=6,
            )
    else:
        _generic_good(kind, rng, wood, dark, brass)


def build_bonus(job: dict, view, rng) -> None:
    kind = job["params"]["type"]
    if kind != "grain":
        _generic_good(
            kind,
            rng,
            _mat("bonus wood", (0.34, 0.21, 0.10)),
            _mat("bonus iron", (0.35, 0.35, 0.33), metallic=0.4),
            _mat("bonus brass", (0.63, 0.45, 0.16), metallic=0.4),
        )
        return
    soil = _mat("grain field soil", (0.38, 0.28, 0.13), roughness=0.95)
    straw = [
        _mat("ripe wheat", (0.78, 0.57, 0.15), roughness=0.9),
        _mat("wheat highlight", (0.91, 0.72, 0.25), roughness=0.88),
    ]
    common.box("grain field", (1.25, 0.72, 0.07), (0.0, 0.0, 0.035), soil, bevel=0.08)
    for row in range(5):
        y = -0.28 + row * 0.14
        for column in range(8):
            x = -0.52 + column * 0.15 + (row % 2) * 0.04
            height = rng.uniform(0.36, 0.56)
            lean = rng.uniform(-0.14, 0.14)
            mat = rng.choice(straw)
            common.limb(
                "wheat stalk", (x, y, 0.08), (x + lean * 0.5, y, height), 0.012, 0.008, mat, segments=5
            )
            common.limb(
                "wheat head",
                (x + lean * 0.5, y, height - 0.02),
                (x + lean, y, height + 0.12),
                0.025,
                0.012,
                mat,
                segments=5,
            )
            for awn in (-1, 1):
                common.limb(
                    "grain awn",
                    (x + lean, y, height + 0.03),
                    (x + lean + awn * 0.045, y, height + 0.12),
                    0.008,
                    0.002,
                    mat,
                    segments=4,
                    rounded=False,
                )


def build_lost_city(job: dict, view, rng) -> None:
    stone = _mat(
        "ancient limestone", (0.58, 0.50, 0.36), roughness=0.95, variation=0.22, scale=12.0, bump=0.16
    )
    worn = _mat("weathered stone", (0.37, 0.34, 0.27), roughness=0.96, variation=0.26)
    gold = _mat("buried treasure", (0.72, 0.47, 0.11), roughness=0.3, metallic=0.65)
    moss = _mat("ruin moss", (0.22, 0.31, 0.12), roughness=0.98)
    common.box("ruin ground", (1.35, 0.86, 0.07), (0.0, 0.0, 0.035), moss, bevel=0.10)
    for index, (x, height, lean) in enumerate(
        ((-0.42, 0.73, 0.07), (-0.12, 0.55, -0.06), (0.19, 0.88, 0.04), (0.45, 0.49, -0.09))
    ):
        common.limb(
            "broken column",
            (x, 0.07, 0.08),
            (x + lean, 0.07, height),
            0.12,
            0.105,
            stone if index % 2 else worn,
            segments=12,
        )
        common.cylinder("column base", 0.16, 0.08, (x, 0.07, 0.10), stone, segments=12)
        common.cylinder("column capital", 0.15, 0.07, (x + lean, 0.07, height - 0.02), stone, segments=12)
    common.box(
        "fallen lintel",
        (0.54, 0.20, 0.13),
        (0.30, 0.04, 0.63),
        stone,
        rotation=(0.0, 0.0, math.radians(-13)),
        bevel=0.03,
    )
    for _ in range(12):
        x, y = rng.uniform(-0.62, 0.62), rng.uniform(-0.35, 0.35)
        size = rng.uniform(0.055, 0.13)
        common.sphere(
            "fallen masonry",
            size,
            (x, y, 0.07 + size * 0.35),
            rng.choice((stone, worn)),
            scale=(1.3, 0.9, 0.65),
            subdivisions=1,
            jitter=0.02,
            seed=rng.randrange(50000),
        )
    common.box(
        "treasure chest",
        (0.35, 0.25, 0.25),
        (0.0, -0.25, 0.20),
        _mat("old chest wood", (0.26, 0.15, 0.07), bands=14.0),
        bevel=0.045,
    )
    common.cylinder(
        "chest lid",
        0.18,
        0.26,
        (0.0, -0.25, 0.36),
        _mat("chest lid wood", (0.33, 0.20, 0.09)),
        radius2=0.14,
        segments=12,
    )
    for x in (-0.09, 0.09):
        common.box("chest band", (0.035, 0.27, 0.28), (x, -0.27, 0.25), gold, bevel=0.01)
    common.box("chest lock", (0.07, 0.025, 0.09), (0.0, -0.386, 0.24), gold, bevel=0.01)
