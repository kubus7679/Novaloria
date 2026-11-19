"""Hand-built colonial figures with readable silhouettes at FreeCol sprite scale."""

from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

from . import common

FIGURE_SUN_FROM = Vector((-0.45, -1.0, 2.5))
FIGURE_CAMERA_SCALE = 3.3
FIGURE_CAMERA_CENTER = 1.32


def frame_figure(view, resolution) -> None:
    """Keep the same person scale and ground anchor regardless of equipment or mount."""
    common.camera(view, view.up * FIGURE_CAMERA_CENTER, FIGURE_CAMERA_SCALE, resolution)


def _m(name, color, roughness=0.78, metallic=0.0, **kwargs):
    kwargs.setdefault("variation", 0.12)
    kwargs.setdefault("scale", 18.0)
    return common.material(name, color, roughness=roughness, metallic=metallic, **kwargs)


def _hat(x, y, z, dark, tricorne=False, band=None):
    common.cylinder("hat brim", 0.19, 0.035, (x, y, z), dark, segments=24)
    common.cylinder("hat crown", 0.115, 0.12, (x, y, z + 0.07), dark, radius2=0.10, segments=20)
    if band is not None:
        common.cylinder("hat band", 0.117, 0.028, (x, y, z + 0.04), band, segments=20)
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
    soldier = profession in {"soldier", "dragoon"} or role in {
        "soldier", "infantry", "dragoon", "cavalry", "armedBrave", "nativeDragoon"
    }
    mounted = mounted or role in {"scout", "dragoon", "cavalry", "mountedBrave", "nativeDragoon"}
    trade = profession if role in {"", "civilian"} and not mounted else ""
    civilian_colors = ((0.38, 0.22, 0.12), (0.24, 0.31, 0.26), (0.36, 0.27, 0.17), (0.33, 0.22, 0.28))
    color_index = sum(ord(character) for character in profession) % len(civilian_colors)
    trade_colors = {
        "colonist": (0.39, 0.39, 0.38),
        "freeColonist": (0.39, 0.39, 0.38),
        "colonialRegular": (0.30, 0.33, 0.34),
        "elderStatesman": (0.35, 0.24, 0.39),
        "expertFarmer": (0.42, 0.36, 0.19),
        "expertFisherman": (0.19, 0.34, 0.42),
        "expertFurTrapper": (0.34, 0.26, 0.18),
        "expertLumberJack": (0.40, 0.22, 0.14),
        "expertOreMiner": (0.26, 0.29, 0.27),
        "expertSilverMiner": (0.36, 0.39, 0.43),
        "firebrandPreacher": (0.23, 0.22, 0.28),
        "hardyPioneer": (0.34, 0.35, 0.23),
        "indenturedServant": (0.51, 0.46, 0.37),
        "jesuitMissionary": (0.17, 0.18, 0.19),
        "kingsRegular": (0.47, 0.16, 0.12),
        "masterBlacksmith": (0.25, 0.24, 0.23),
        "masterCarpenter": (0.48, 0.32, 0.18),
        "masterCottonPlanter": (0.53, 0.48, 0.36),
        "masterDistiller": (0.32, 0.36, 0.25),
        "masterFurTrader": (0.40, 0.25, 0.17),
        "masterGunsmith": (0.30, 0.30, 0.31),
        "masterSugarPlanter": (0.47, 0.45, 0.25),
        "masterTobaccoPlanter": (0.34, 0.38, 0.20),
        "masterTobacconist": (0.41, 0.24, 0.20),
        "masterWeaver": (0.31, 0.29, 0.46),
        "pettyCriminal": (0.43, 0.40, 0.33),
        "revenger": (0.24, 0.27, 0.30),
        "seasonedScout": (0.25, 0.34, 0.23),
        "undead": (0.30, 0.33, 0.27),
        "veteranSoldier": (0.20, 0.27, 0.37),
    }
    coat_color = (
        (0.48, 0.14, 0.10)
        if soldier and profession == "kingsRegular"
        else (0.22, 0.30, 0.39)
        if soldier and profession == "colonialRegular"
        else (0.12, 0.20, 0.34)
        if soldier
        else (0.38, 0.20, 0.11)
        if native
        else (0.45, 0.20, 0.13)
        if mounted and profession == "kingsRegular"
        else (0.25, 0.32, 0.18)
        if mounted and profession == "seasonedScout"
        else (0.16, 0.26, 0.16)
        if mounted
        else trade_colors.get(trade, civilian_colors[color_index])
    )
    coat = _m("wool coat", coat_color, roughness=0.85)
    trim = _m("coat trim", (0.70, 0.53, 0.27))
    shirt = _m("linen shirt", (0.84, 0.78, 0.63) if not native else (0.68, 0.48, 0.26))
    skin_color = (0.46, 0.51, 0.39) if profession in {"undead", "revenger"} else (
        (0.55, 0.31, 0.19) if native else (0.67, 0.39, 0.24)
    )
    skin = _m("warm skin", skin_color, roughness=0.7)
    leather = _m("dark leather", (0.20, 0.12, 0.07))
    hair = _m("hair", (0.18, 0.105, 0.055), roughness=0.9)
    breeches = _m(
        "breeches", (0.66, 0.55, 0.38) if soldier else (0.43, 0.34, 0.21) if native else (0.39, 0.31, 0.22)
    )
    metal = _m("iron", (0.45, 0.48, 0.47), roughness=0.32, metallic=0.65)
    buttons = _m("brass buttons", (0.79, 0.62, 0.32), roughness=0.36, metallic=0.55)

    def point(p):
        return (p[0] + ox, p[1] + oy, p[2] + oz)

    # Boots, legs and coat skirt.
    for side in (-1, 1):
        if mounted:
            hip = (side * 0.09, 0.0, 0.73)
            knee = (side * 0.35, -0.12, 0.50)
            ankle = (side * 0.35, -0.12, 0.17)
            common.limb("rider thigh", point(hip), point(knee), 0.075, 0.065, breeches)
            common.limb("rider lower leg", point(knee), point(ankle), 0.055, 0.045, breeches)
            common.box("rider boot", (0.12, 0.22, 0.12), point((side * 0.35, -0.16, 0.13)),
                       leather, bevel=0.025)
            common.cylinder("rider boot cuff", 0.06, 0.07, point((side * 0.35, -0.12, 0.25)),
                            leather, segments=12)
        else:
            x = side * 0.105
            common.box("boot", (0.12, 0.22, 0.10), point((x, -0.035, 0.055)), leather, bevel=0.025)
            common.cylinder("boot cuff", 0.057, 0.075, point((x, 0.0, 0.17)), leather, segments=12)
            common.limb("stocking", point((x, 0.0, 0.10)), point((x, 0.0, 0.43)), 0.048, 0.052, breeches)
            common.limb("leg", point((x, 0.0, 0.40)), point((x * 0.82, 0.0, 0.68)), 0.058, 0.07, breeches)
    if mounted:
        common.cylinder("coat skirt", 0.19, 0.23, point((0.0, 0.0, 0.82)), coat, radius2=0.155, segments=20)
    else:
        common.cylinder("coat skirt", 0.235, 0.36, point((0.0, 0.0, 0.82)), coat, radius2=0.155, segments=20)
    common.cylinder(
        "waist sash", 0.16, 0.075, point((0.0, 0.0, 0.98)), trim if soldier else leather, segments=20
    )
    common.limb("coat torso", point((0.0, 0.0, 1.00)), point((0.0, 0.0, 1.42)), 0.19, 0.155, coat)
    common.box("waistcoat", (0.12, 0.03, 0.33), point((0.0, -0.175, 1.20)), shirt, bevel=0.015)
    for side in (-1, 1):
        common.limb("coat lapel", point((side * 0.13, -0.17, 1.40)),
                    point((side * 0.035, -0.19, 1.15)), 0.025, 0.018, coat, segments=7)
        common.box("coat pocket", (0.11, 0.025, 0.035), point((side * 0.14, -0.195, 0.87)),
                   leather, bevel=0.008)
    for z in (1.04, 1.14, 1.24):
        common.sphere("waistcoat button", 0.017, point((0.0, -0.198, z)), buttons, subdivisions=2)
    common.box("belt buckle", (0.075, 0.025, 0.055), point((0.0, -0.165, 0.97)), buttons, bevel=0.01)
    if trade == "masterBlacksmith":
        common.box("smith leather apron", (0.32, 0.055, 0.70), point((0.0, -0.18, 0.85)), leather,
                   bevel=0.025)
        common.limb("apron strap", point((-0.15, -0.16, 1.12)), point((0.12, -0.14, 1.43)),
                    0.024, 0.024, leather)
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
            common.box("red cuff", (0.09, 0.11, 0.08), point((side * 0.22, -0.02, 1.05)),
                       _m("red uniform cuff", (0.57, 0.13, 0.09)), bevel=0.018)
    # Arms, hands and collar.
    for side in (-1, 1):
        shoulder = point((side * 0.16, 0.0, 1.34))
        elbow = point((side * 0.25, -0.015, 1.12))
        hand = point((side * (0.29 if side < 0 else 0.30), -0.04, 0.98))
        if mounted:
            elbow, hand = point((side * 0.23, -0.17, 1.19)), point((side * 0.17, -0.34, 1.12))
        common.limb("sleeve", shoulder, elbow, 0.085, 0.065, coat)
        common.limb("forearm", elbow, hand, 0.06, 0.045, coat if not soldier else trim)
        common.sphere("hand", 0.055, hand, skin, scale=(0.8, 0.75, 0.85), subdivisions=2)
    common.cylinder("neck", 0.07, 0.12, point((0.0, 0.0, 1.48)), skin, segments=14)
    common.sphere("head", 0.145, point((0.0, -0.01, 1.65)), skin, scale=(0.88, 0.86, 1.12), subdivisions=3)
    common.sphere(
        "hair back", 0.15, point((0.0, 0.045, 1.69)), hair, scale=(0.92, 0.72, 1.08), subdivisions=2
    )
    common.sphere("nose", 0.04, point((0.0, -0.135, 1.64)), skin, scale=(0.65, 1.0, 0.65), subdivisions=2)
    for side in (-1, 1):
        common.sphere("ear", 0.038, point((side * 0.13, -0.015, 1.65)), skin,
                      scale=(0.55, 0.75, 1.0), subdivisions=2)
        common.sphere("eye", 0.018, point((side * 0.062, -0.133, 1.69)), hair,
                      scale=(1.0, 0.45, 0.65), subdivisions=2)
    common.limb("collar", point((-0.11, -0.12, 1.44)), point((0.11, -0.12, 1.44)),
                0.025, 0.025, shirt, segments=8)
    if not native and (not mounted or not soldier):
        _hat(
            ox,
            oy - 0.01,
            oz + 1.79,
            _m("straw hat", (0.76, 0.62, 0.34)) if trade == "expertFarmer"
            else leather if not soldier else _m("black tricorn", (0.07, 0.07, 0.065)),
            soldier,
            band=leather if trade == "expertFarmer" else trim,
        )
    elif mounted and not native:
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
    if mounted and soldier:
        blade = _m("saber steel", (0.75, 0.78, 0.77), roughness=0.22, metallic=0.8)
        common.limb(
            "saber",
            point((-0.17, -0.34, 1.12)),
            point((-0.40, -0.42, 1.63)),
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
            point((-0.17, -0.34, 1.12)),
            trim,
            segments=12,
            rotation=(0.0, math.pi / 2, 0.0),
        )
    if native:
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
    if trade == "expertFarmer":
        wheat = _m("golden wheat", (0.86, 0.63, 0.20))
        common.box("farmer neckerchief", (0.19, 0.035, 0.09), point((0.0, -0.17, 1.39)), shirt,
                   bevel=0.015)
        for index in range(5):
            x = -0.38 + index * 0.045
            tip = 1.32 + (index % 2) * 0.08
            common.limb("harvest stalk", point((-0.29, -0.19, 0.70)), point((x, -0.19, tip)),
                        0.012, 0.009, wheat, segments=6)
            common.sphere("wheat ear", 0.065, point((x, -0.19, tip)), wheat,
                          scale=(0.46, 0.45, 1.65), subdivisions=2)
    elif trade == "expertFisherman":
        fish = _m("silver blue fish", (0.58, 0.68, 0.70), roughness=0.35, metallic=0.3)
        common.limb("fisherman sash", point((-0.14, -0.18, 1.39)), point((0.15, -0.18, 1.02)),
                    0.025, 0.025, shirt, segments=7)
        common.limb("fishing pole", point((-0.30, -0.15, 0.73)), point((-0.52, -0.15, 1.72)),
                    0.025, 0.009, _m("fishing pole wood", (0.45, 0.29, 0.15)), segments=7)
        common.sphere("caught fish", 0.14, point((-0.39, -0.20, 0.63)), fish,
                      scale=(0.60, 0.45, 1.4), subdivisions=2)
        common.limb("fish tail", point((-0.39, -0.20, 0.48)), point((-0.39, -0.20, 0.38)),
                    0.025, 0.08, fish, segments=5, rounded=False)
        common.sphere("fish eye", 0.018, point((-0.39, -0.27, 0.72)), hair, subdivisions=2)
    elif trade == "expertLumberJack":
        common.limb("axe handle", point((-0.31, -0.17, 0.65)), point((-0.38, -0.17, 1.48)),
                    0.027, 0.024, leather, segments=8)
        bm = bmesh.new()
        vertices = [bm.verts.new(point(p)) for p in (
            (-0.37, -0.18, 1.36), (-0.37, -0.18, 1.45),
            (-0.62, -0.18, 1.54), (-0.62, -0.18, 1.27),
        )]
        bm.faces.new(vertices)
        axe = common.from_bmesh("axe head", bm, metal, smooth=False)
        axe.modifiers.new("axe blade thickness", "SOLIDIFY").thickness = 0.06
    elif trade == "masterBlacksmith":
        common.limb("smith hammer handle", point((-0.30, -0.17, 0.70)), point((-0.37, -0.17, 1.26)),
                    0.029, 0.025, leather, segments=8)
        common.box("smith hammer head", (0.25, 0.12, 0.13), point((-0.37, -0.17, 1.27)), metal, bevel=0.015)
        for side in (-1, 1):
            common.limb("smith tongs", point((0.28, -0.18, 0.94)), point((0.31 + side * 0.055, -0.18, 0.62)),
                        0.014, 0.009, metal, segments=6)
    if not mounted:
        detail = role if role in {"missionary", "pioneer"} else trade
        _profession_details(detail, point, leather, metal, trim, shirt)
    if trade == "brave":
        common.limb("brave spear", point((-0.31, -0.10, 0.48)), point((-0.39, -0.10, 1.77)),
                    0.020, 0.015, leather, segments=7)
        common.limb("spear tip", point((-0.39, -0.10, 1.76)), point((-0.40, -0.10, 1.96)),
                    0.035, 0.0, metal, segments=5, rounded=False)
    elif trade == "nativeColonist":
        common.box("colonist work pouch", (0.18, 0.10, 0.22), point((-0.30, -0.17, 0.82)),
                   leather, bevel=0.035)
    if mounted and role == "scout" and profession == "seasonedScout":
        common.limb("mounted scout spyglass", point((0.20, 0.07, 0.92)), point((0.26, 0.07, 1.25)),
                    0.04, 0.025, buttons, segments=10)
    if profession in {"veteranSoldier", "colonialRegular", "kingsRegular"}:
        for side in (-1, 1):
            common.box("uniform shoulder tab", (0.13, 0.10, 0.035), point((side * 0.16, 0.0, 1.40)),
                       buttons, bevel=0.012)


def _profession_details(kind, point, leather, metal, brass, linen):
    wood = _m("tool wood", (0.51, 0.32, 0.16), bands=12.0)
    if kind in {"expertOreMiner", "expertSilverMiner"}:
        common.limb("miner pick handle", point((-0.30, -0.17, 0.69)), point((-0.38, -0.17, 1.48)),
                    0.025, 0.025, wood, segments=8)
        common.limb("miner pick head", point((-0.58, -0.17, 1.37)), point((-0.20, -0.17, 1.48)),
                    0.018, 0.018, metal, segments=6)
        ore = _m("silver ore" if kind == "expertSilverMiner" else "iron ore",
                 (0.74, 0.76, 0.75) if kind == "expertSilverMiner" else (0.33, 0.24, 0.19),
                 metallic=0.4)
        common.sphere("miner's sample", 0.11, point((0.27, -0.13, 0.77)), ore,
                      scale=(0.8, 0.65, 1.0), subdivisions=1)
    elif kind in {"hardyPioneer", "pioneer"}:
        common.limb("pioneer shovel handle", point((-0.32, -0.15, 0.55)), point((-0.35, -0.15, 1.48)),
                    0.027, 0.024, wood, segments=8)
        common.box("pioneer shovel blade", (0.19, 0.07, 0.26), point((-0.32, -0.15, 0.48)),
                   metal, bevel=0.045)
        common.box("pioneer pack", (0.31, 0.19, 0.35), point((0.0, 0.20, 1.20)), leather, bevel=0.04)
    elif kind == "masterCarpenter":
        common.limb("carpenter saw handle", point((-0.30, -0.16, 0.92)), point((-0.40, -0.16, 1.05)),
                    0.045, 0.04, wood, segments=8)
        common.box("carpenter saw blade", (0.25, 0.035, 0.40), point((-0.44, -0.16, 1.22)),
                   metal, rotation=(0.0, -0.18, 0.0), bevel=0.01)
        common.box("carpenter apron", (0.31, 0.04, 0.45), point((0.0, -0.20, 0.83)), linen, bevel=0.02)
    elif kind in {"expertFurTrapper", "masterFurTrader"}:
        fur = _m("fur wrap", (0.50, 0.30, 0.14), roughness=0.96, variation=0.24)
        common.sphere("fur pelt", 0.20, point((-0.33, -0.16, 0.82)), fur,
                      scale=(0.65, 0.40, 1.35), subdivisions=2, jitter=0.03, seed=3)
        common.limb("pelt tie", point((-0.45, -0.24, 0.90)), point((-0.22, -0.24, 0.90)),
                    0.014, 0.014, linen, segments=6)
        if kind == "expertFurTrapper":
            common.limb("trapper long rifle", point((0.28, 0.12, 0.62)), point((0.29, 0.12, 1.65)),
                        0.026, 0.012, wood, segments=8)
        else:
            common.sphere("trader medallion", 0.045, point((0.04, -0.20, 1.14)), brass, subdivisions=2)
    elif kind in {"masterCottonPlanter", "masterSugarPlanter", "masterTobaccoPlanter"}:
        green = _m("plant stalk", (0.35, 0.43, 0.18))
        for index in range(3):
            x = -0.39 + index * 0.055
            tip = 1.31 + index * 0.045
            common.limb("planter stalk", point((-0.30, -0.17, 0.72)), point((x, -0.17, tip)),
                        0.016, 0.012, green, segments=7)
            if kind == "masterCottonPlanter":
                common.sphere("planter cotton boll", 0.065, point((x, -0.17, tip)), linen, subdivisions=2)
            else:
                leaf = _m("planter leaf", (0.51, 0.45, 0.15) if kind == "masterTobaccoPlanter"
                          else (0.43, 0.55, 0.22))
                common.sphere("planter crop leaf", 0.10, point((x - 0.04, -0.17, tip - 0.14)), leaf,
                              scale=(0.75, 0.25, 1.4) if kind == "masterTobaccoPlanter"
                              else (0.28, 0.20, 2.1), subdivisions=2)
    elif kind == "masterDistiller":
        glass = _m("distiller green glass", (0.12, 0.32, 0.23), roughness=0.25)
        common.cylinder("distiller bottle", 0.085, 0.25, point((-0.32, -0.17, 0.79)), glass, segments=12)
        common.cylinder("distiller bottle neck", 0.038, 0.09, point((-0.32, -0.17, 0.95)), glass, segments=10)
        common.box("bottle label", (0.09, 0.02, 0.09), point((-0.32, -0.26, 0.79)), linen, bevel=0.01)
    elif kind == "masterGunsmith":
        common.limb("gunsmith stock", point((-0.34, -0.17, 0.69)), point((-0.38, -0.17, 1.45)),
                    0.032, 0.024, wood, segments=8)
        common.limb("gunsmith barrel", point((-0.38, -0.17, 1.27)), point((-0.39, -0.17, 1.72)),
                    0.014, 0.009, metal, segments=8)
        common.box("gunsmith apron", (0.30, 0.05, 0.48), point((0.0, -0.20, 0.81)), leather, bevel=0.02)
    elif kind == "masterTobacconist":
        tobacco = _m("rolled tobacco", (0.39, 0.20, 0.09))
        common.box("tobacconist box", (0.23, 0.16, 0.16), point((-0.34, -0.17, 0.80)), wood, bevel=0.02)
        for index in range(3):
            common.limb("cigar", point((-0.43 + index * 0.08, -0.18, 0.87)),
                        point((-0.43 + index * 0.08, -0.18, 1.04)), 0.025, 0.020, tobacco, segments=8)
    elif kind == "masterWeaver":
        blue = _m("weaver textile", (0.27, 0.43, 0.65))
        common.cylinder("weaver cloth roll", 0.11, 0.34, point((-0.34, -0.17, 0.83)), blue,
                        segments=16, rotation=(0.0, math.pi / 2, 0.0))
        common.cylinder("weaver roll end", 0.075, 0.02, point((-0.52, -0.17, 0.83)), linen,
                        segments=12, rotation=(0.0, math.pi / 2, 0.0))
    elif kind in {"jesuitMissionary", "firebrandPreacher", "missionary", "indianConvert"}:
        common.box("prayer book", (0.22, 0.11, 0.25), point((-0.33, -0.17, 0.83)), leather, bevel=0.02)
        common.limb("book cross vertical", point((-0.33, -0.24, 0.76)), point((-0.33, -0.24, 0.90)),
                    0.012, 0.012, brass, segments=6)
        common.limb("book cross horizontal", point((-0.38, -0.24, 0.85)), point((-0.28, -0.24, 0.85)),
                    0.012, 0.012, brass, segments=6)
    elif kind == "elderStatesman":
        common.cylinder("statesman scroll", 0.055, 0.34, point((-0.33, -0.17, 0.82)), linen,
                        segments=14, rotation=(0.0, math.pi / 2, 0.0))
        common.box("statesman sash", (0.07, 0.04, 0.48), point((0.05, -0.20, 1.17)),
                   brass, rotation=(0.0, -0.35, 0.0), bevel=0.01)
    elif kind == "seasonedScout":
        common.box("scout pack", (0.31, 0.20, 0.36), point((0.0, 0.21, 1.21)), leather, bevel=0.04)
        common.limb("scout spyglass", point((-0.30, -0.16, 0.82)), point((-0.42, -0.16, 1.14)),
                    0.045, 0.03, brass, segments=10)
    elif kind in {"pettyCriminal", "indenturedServant"}:
        common.box("worn coat patch", (0.13, 0.025, 0.12), point((0.13, -0.19, 0.91)),
                   linen, rotation=(0.0, 0.12, 0.0), bevel=0.01)
        if kind == "pettyCriminal":
            common.limb("prisoner wrist chain", point((-0.28, -0.05, 0.94)),
                        point((0.29, -0.05, 0.94)), 0.012, 0.012, metal, segments=6)
    elif kind in {"undead", "revenger"}:
        common.limb("tattered coat hem", point((-0.20, -0.15, 0.68)), point((0.18, -0.15, 0.60)),
                    0.025, 0.012, leather, segments=6)


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
        y = side * 0.11
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
    for side in (-1, 1):
        y = side * 0.17
        common.limb("bridle", (-0.68, side * 0.10, 1.48), (-0.50, side * 0.15, 1.35),
                    0.018, 0.012, dark, segments=8)
        common.limb("reins", (-0.50, side * 0.15, 1.35), (-0.32, y, 1.77),
                    0.012, 0.01, dark, segments=6)
        common.limb("stirrup strap", (0.02, side * 0.17, 1.35), (-0.12, side * 0.35, 0.73),
                    0.022, 0.018, dark, segments=7)
        common.box("stirrup", (0.22, 0.08, 0.04), (-0.16, side * 0.35, 0.72), metal, bevel=0.01)


def build_figure(job: dict, view, rng) -> None:
    profession = job["params"]["profession"]
    role = job["params"].get("role", "")
    unit = job["params"].get("unit", "")
    if job["params"].get("mounted"):
        _horse(rng)
        before = set(bpy.context.scene.objects)
        _person(profession, mounted=True, role=role, unit=unit)
        bpy.context.view_layer.update()
        transform = Matrix.Translation((0.02, 0.0, 0.65)) @ Matrix.Rotation(-math.pi / 2, 4, "Z")
        for obj in bpy.context.scene.objects:
            if obj not in before:
                obj.matrix_world = transform @ obj.matrix_world
    else:
        _person(profession, role=role, unit=unit)
