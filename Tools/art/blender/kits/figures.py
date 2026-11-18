"""Hand-built colonial figures with readable silhouettes at FreeCol sprite scale."""

from __future__ import annotations

import math

from . import common


def _m(name, color, roughness=0.78, metallic=0.0, **kwargs):
    kwargs.setdefault("variation", 0.12)
    kwargs.setdefault("scale", 18.0)
    return common.material(name, color, roughness=roughness, metallic=metallic, **kwargs)


def _hat(x, y, z, dark, tricorne=False):
    common.cylinder("hat brim", 0.19, 0.035, (x, y, z), dark, segments=24)
    common.cylinder("hat crown", 0.115, 0.12, (x, y, z + 0.07), dark, radius2=0.10, segments=20)
    if tricorne:
        for angle in (0.0, 2.0 * math.pi / 3.0, 4.0 * math.pi / 3.0):
            point = (x + math.cos(angle) * 0.16, y + math.sin(angle) * 0.16, z + 0.06)
            common.sphere(
                "tricorne upturned brim", 0.072, point, dark, scale=(1.15, 0.72, 0.38), subdivisions=2
            )


def _person(profession: str, origin=(0.0, 0.0, 0.0), mounted=False, role="", unit=""):
    ox, oy, oz = origin
    identity = f"{profession}:{role}:{unit}".lower()
    native = any(token in identity for token in ("native", "brave", "indian", "aztec", "inca"))
    soldier = profession == "soldier" or role in {"soldier", "infantry", "armedBrave", "nativeDragoon"}
    mounted = mounted or role in {"dragoon", "cavalry", "mountedBrave", "nativeDragoon"}
    civilian_colors = ((0.38, 0.22, 0.12), (0.24, 0.31, 0.26), (0.36, 0.27, 0.17), (0.33, 0.22, 0.28))
    color_index = sum(ord(character) for character in profession) % len(civilian_colors)
    coat_color = (
        (0.12, 0.20, 0.34)
        if soldier
        else (0.38, 0.20, 0.11)
        if native
        else (0.16, 0.26, 0.16)
        if mounted
        else civilian_colors[color_index]
    )
    coat = _m("wool coat", coat_color, roughness=0.85)
    trim = _m("coat trim", (0.70, 0.53, 0.27))
    shirt = _m("linen shirt", (0.84, 0.78, 0.63) if not native else (0.68, 0.48, 0.26))
    skin = _m("warm skin", (0.55, 0.31, 0.19) if native else (0.67, 0.39, 0.24), roughness=0.7)
    leather = _m("dark leather", (0.20, 0.12, 0.07))
    hair = _m("hair", (0.18, 0.105, 0.055), roughness=0.9)
    breeches = _m(
        "breeches", (0.66, 0.55, 0.38) if soldier else (0.43, 0.34, 0.21) if native else (0.39, 0.31, 0.22)
    )
    metal = _m("iron", (0.45, 0.48, 0.47), roughness=0.32, metallic=0.65)

    def point(p):
        return (p[0] + ox, p[1] + oy, p[2] + oz)

    # Boots, legs and coat skirt.
    for side in (-1, 1):
        x = side * 0.105
        common.box("boot", (0.12, 0.22, 0.10), point((x, -0.035, 0.055)), leather, bevel=0.025)
        common.limb("stocking", point((x, 0.0, 0.10)), point((x, 0.0, 0.43)), 0.048, 0.052, breeches)
        common.limb("leg", point((x, 0.0, 0.40)), point((x * 0.82, 0.0, 0.68)), 0.058, 0.07, breeches)
    common.cylinder("coat skirt", 0.235, 0.36, point((0.0, 0.0, 0.82)), coat, radius2=0.155, segments=20)
    common.cylinder(
        "waist sash", 0.16, 0.075, point((0.0, 0.0, 0.98)), trim if soldier else leather, segments=20
    )
    common.limb("coat torso", point((0.0, 0.0, 1.00)), point((0.0, 0.0, 1.42)), 0.19, 0.155, coat)
    common.box("waistcoat", (0.12, 0.03, 0.33), point((0.0, -0.103, 1.20)), shirt, bevel=0.015)
    if soldier:
        for side in (-1, 1):
            common.limb(
                "cross belt",
                point((side * 0.12, -0.12, 1.40)),
                point((-side * 0.11, -0.12, 0.87)),
                0.025,
                0.025,
                shirt,
                segments=8,
            )
            common.box("red cuff", (0.09, 0.11, 0.08), point((side * 0.22, -0.02, 1.05)), trim, bevel=0.018)
    # Arms, hands and collar.
    for side in (-1, 1):
        shoulder = point((side * 0.16, 0.0, 1.34))
        elbow = point((side * 0.25, -0.015, 1.12))
        hand = point((side * (0.29 if side < 0 else 0.30), -0.04, 0.98))
        if mounted and side < 0:
            elbow, hand = point((-0.26, -0.03, 1.35)), point((-0.24, -0.10, 1.47))
        common.limb("sleeve", shoulder, elbow, 0.085, 0.065, coat)
        common.limb("forearm", elbow, hand, 0.06, 0.045, coat if not soldier else trim)
        common.sphere("hand", 0.055, hand, skin, scale=(0.8, 0.75, 0.85), subdivisions=2)
    common.cylinder("neck", 0.07, 0.12, point((0.0, 0.0, 1.48)), skin, segments=14)
    common.sphere("head", 0.145, point((0.0, -0.01, 1.65)), skin, scale=(0.88, 0.86, 1.12), subdivisions=3)
    common.sphere(
        "hair back", 0.15, point((0.0, 0.045, 1.69)), hair, scale=(0.92, 0.72, 1.08), subdivisions=2
    )
    common.sphere("nose", 0.04, point((0.0, -0.135, 1.64)), skin, scale=(0.65, 1.0, 0.65), subdivisions=2)
    if not mounted and not native:
        _hat(
            ox,
            oy - 0.01,
            oz + 1.79,
            leather if not soldier else _m("black tricorn", (0.07, 0.07, 0.065)),
            soldier,
        )
    elif mounted:
        helmet = _m("dragoon helmet", (0.45, 0.39, 0.24), metallic=0.38)
        common.sphere(
            "helmet", 0.16, point((0.0, -0.01, 1.80)), helmet, scale=(1.0, 0.9, 0.55), subdivisions=2
        )
        common.limb(
            "helmet crest",
            point((0.0, -0.01, 1.84)),
            point((0.0, -0.01, 2.02)),
            0.025,
            0.01,
            _m("red plume", (0.58, 0.11, 0.07)),
        )
    # Equipment is on the figure's right (camera-visible) side.
    if soldier:
        common.limb(
            "musket stock",
            point((-0.31, -0.09, 0.74)),
            point((-0.31, -0.09, 1.56)),
            0.035,
            0.025,
            leather,
            segments=10,
        )
        common.limb(
            "musket barrel",
            point((-0.31, -0.095, 1.25)),
            point((-0.31, -0.095, 1.92)),
            0.012,
            0.008,
            metal,
            segments=8,
            rounded=False,
        )
        common.limb(
            "bayonet",
            point((-0.31, -0.095, 1.91)),
            point((-0.31, -0.095, 2.10)),
            0.012,
            0.0,
            metal,
            segments=6,
            rounded=False,
        )
    if mounted:
        blade = _m("saber steel", (0.75, 0.78, 0.77), roughness=0.22, metallic=0.8)
        common.limb(
            "saber",
            point((-0.28, -0.16, 1.43)),
            point((-0.46, -0.16, 1.91)),
            0.018,
            0.006,
            blade,
            segments=8,
            rounded=False,
        )
        common.cylinder(
            "saber guard",
            0.055,
            0.018,
            point((-0.28, -0.16, 1.47)),
            trim,
            segments=12,
            rotation=(0.0, math.pi / 2, 0.0),
        )
    else:
        common.limb(
            "woven headband",
            point((-0.15, -0.02, 1.77)),
            point((0.15, -0.02, 1.77)),
            0.025,
            0.025,
            trim,
            segments=8,
        )
        for side in (-1, 1):
            common.limb(
                "feather",
                point((side * 0.08, 0.0, 1.78)),
                point((side * 0.17, 0.0, 2.03)),
                0.035,
                0.004,
                _m("feather pigment", (0.61, 0.15, 0.08)),
                segments=7,
            )


def _horse(rng):
    hide = _m("chestnut horse", (0.34, 0.16, 0.075), roughness=0.78, variation=0.2)
    dark = _m("mane and tack", (0.12, 0.075, 0.045), roughness=0.85)
    blanket = _m("red saddle cloth", (0.48, 0.10, 0.06), roughness=0.82)
    metal = _m("brass tack", (0.55, 0.40, 0.17), metallic=0.35)
    common.sphere("horse barrel", 0.40, (0.0, 0.0, 0.88), hide, scale=(1.45, 0.70, 0.76), subdivisions=3)
    common.sphere("horse hindquarter", 0.29, (0.42, 0.0, 0.91), hide, scale=(1.0, 0.86, 1.05), subdivisions=3)
    common.limb("horse neck", (-0.38, 0.0, 0.96), (-0.56, 0.0, 1.42), 0.21, 0.13, hide)
    common.sphere("horse head", 0.17, (-0.65, -0.015, 1.48), hide, scale=(0.75, 0.75, 1.35), subdivisions=2)
    common.sphere("horse muzzle", 0.095, (-0.75, -0.07, 1.36), hide, scale=(0.8, 0.9, 0.72), subdivisions=2)
    for side in (-1, 1):
        y = side * 0.22
        common.sphere("horse eye", 0.025, (-0.63, y, 1.53), dark, subdivisions=2)
        common.limb(
            "horse ear",
            (-0.60, side * 0.09, 1.58),
            (-0.57, side * 0.09, 1.73),
            0.045,
            0.012,
            hide,
            segments=8,
        )
    for x, fore in ((-0.31, True), (0.38, False)):
        for side in (-1, 1):
            hip = (x, side * 0.18, 0.81 if fore else 0.75)
            hoof = (x - (0.02 if fore else 0.04), side * 0.18, 0.10)
            knee = (x + (0.04 if fore else -0.10), side * 0.20, 0.45)
            common.limb("horse upper leg", hip, knee, 0.09, 0.052, hide)
            common.limb("horse lower leg", knee, hoof, 0.045, 0.035, hide, segments=10)
            common.cylinder("hoof", 0.055, 0.07, (hoof[0], hoof[1], 0.06), dark, segments=10)
    common.limb("horse tail", (0.58, 0.04, 0.98), (0.81, 0.04, 0.62), 0.075, 0.018, dark)
    for index in range(5):
        common.limb(
            "mane",
            (-0.43 - index * 0.035, -0.02, 1.35 - index * 0.04),
            (-0.38 - index * 0.04, -0.02, 1.52 - index * 0.045),
            0.04,
            0.018,
            dark,
            segments=8,
        )
    common.box("saddle blanket", (0.60, 0.50, 0.10), (0.02, 0.0, 1.26), blanket, bevel=0.035)
    common.box("saddle", (0.34, 0.32, 0.12), (0.02, -0.015, 1.34), dark, bevel=0.04)
    common.limb("bridle", (-0.68, -0.12, 1.48), (-0.35, -0.23, 1.03), 0.018, 0.012, dark, segments=8)
    common.limb("reins", (-0.35, -0.23, 1.03), (-0.18, -0.16, 1.43), 0.012, 0.01, metal, segments=6)


def build_figure(job: dict, view, rng) -> None:
    profession = job["params"]["profession"]
    role = job["params"].get("role", "")
    unit = job["params"].get("unit", "")
    if job["params"].get("mounted"):
        _horse(rng)
        _person(profession, (0.04, -0.02, 1.31), mounted=True, role=role, unit=unit)
    else:
        _person(profession, role=role, unit=unit)
