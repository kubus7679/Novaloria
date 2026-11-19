"""Check the identifying geometry of the proposed sprites inside Blender."""

import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "blender"))

import bpy  # noqa: E402
from kits import common, figures, items, vehicles  # noqa: E402
from mathutils import Vector  # noqa: E402


def names():
    return {obj.name.split(".")[0] for obj in bpy.context.scene.objects}


for profession, identifying in (
    ("expertFarmer", {"wheat ear", "hat brim"}),
    ("expertFisherman", {"fishing pole", "caught fish"}),
    ("expertLumberJack", {"axe handle", "axe head"}),
    ("masterBlacksmith", {"smith leather apron", "smith hammer head"}),
    ("freeColonist", {"hat brim"}),
    ("soldier", {"musket barrel", "bayonet"}),
):
    common.reset()
    figures.build_figure({"params": {"profession": profession}}, common.View(18), random.Random(1))
    assert identifying <= names(), (profession, identifying - names())
    assert "feather" not in names(), profession
    assert {"waistcoat button", "belt buckle", "coat lapel", "eye"} <= names(), profession

common.reset()
figures.build_figure({"params": {"profession": "brave", "role": "civilian"}},
                     common.View(18), random.Random(1))
assert "feather" in names()
assert "brave spear" in names()

common.reset()
figures.build_figure({"params": {"profession": "nativeColonist", "role": "civilian"}},
                     common.View(18), random.Random(1))
assert "colonist work pouch" in names()

for profession in ("colonist", "freeColonist"):
    common.reset()
    figures.build_figure({"params": {"profession": profession}}, common.View(18), random.Random(1))
    coat = bpy.data.materials["wool coat"]
    color_node = next(node for node in coat.node_tree.nodes if node.type == "HUE_SAT")
    color = color_node.inputs["Color"].default_value
    assert max(color[:3]) - min(color[:3]) < 0.01, profession


def objects(prefix):
    return [obj for obj in bpy.context.scene.objects if obj.name.split(".")[0] == prefix]


def bounds(obj):
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return tuple((min(point[axis] for point in corners), max(point[axis] for point in corners))
                 for axis in range(3))


for profession, role, native in (
    ("dragoon", "", False),
    ("scout", "scout", False),
    ("seasonedScout", "scout", False),
    ("kingsRegular", "cavalry", False),
    ("brave", "mountedBrave", True),
    ("brave", "nativeDragoon", True),
):
    common.reset()
    figures.build_figure({"params": {"profession": profession, "role": role, "mounted": True}},
                         common.View(18), random.Random(1))
    bpy.context.view_layer.update()
    saddle = bounds(objects("saddle")[0])
    skirt = bounds(objects("coat skirt")[0])
    assert saddle[2][0] <= skirt[2][0] <= saddle[2][1] + 0.02, (profession, role, skirt, saddle)
    assert saddle[0][0] <= sum(skirt[0]) / 2 <= saddle[0][1]
    boots = objects("rider boot")
    assert len(boots) == len(objects("rider thigh")) == len(objects("rider lower leg")) == 2
    assert sorted(round(obj.matrix_world.translation.y, 2) for obj in boots) == [-0.35, 0.35]
    for boot in boots:
        foot = boot.matrix_world.translation
        assert 0.1 < foot.z < saddle[2][0]
        assert min((foot - stirrup.matrix_world.translation).length for stirrup in objects("stirrup")) < 0.10
    for hand in objects("hand"):
        position = hand.matrix_world.translation
        nearest = min(
            (position - rein.matrix_world @ vertex.co).length
            for rein in objects("reins") for vertex in rein.data.vertices
        )
        assert nearest < 0.035, (profession, role, nearest)
    assert ("feather" in names()) == native
    if profession == "seasonedScout":
        assert "mounted scout spyglass" in names()

for good, identifying in (
    ("grain", {"wheat stalk", "wheat ear", "grain awn", "sheaf binding"}),
    ("cotton", {"cotton bale", "cotton tuft", "cotton tuft lobe", "bale top tie"}),
    ("tobacco", {"broad tobacco leaf", "tobacco leaf vein", "tobacco leaf rib"}),
    ("cloth", {"folded blue cloth", "cloth roll", "roll core", "linen fold edge"}),
    ("coats", {"folded coat body", "coat sleeve", "coat cuff", "coat button"}),
):
    common.reset()
    items.build_goods({"params": {"type": good}}, common.View(35), random.Random(1))
    assert identifying <= names(), (good, identifying - names())

for profession, identifying in (
    ("expertFurTrapper", "trapper long rifle"),
    ("expertOreMiner", "miner pick head"),
    ("expertSilverMiner", "miner's sample"),
    ("hardyPioneer", "pioneer shovel blade"),
    ("masterCarpenter", "carpenter saw blade"),
    ("masterCottonPlanter", "planter cotton boll"),
    ("masterSugarPlanter", "planter crop leaf"),
    ("masterTobaccoPlanter", "planter crop leaf"),
    ("masterDistiller", "distiller bottle"),
    ("masterFurTrader", "trader medallion"),
    ("masterGunsmith", "gunsmith barrel"),
    ("masterTobacconist", "cigar"),
    ("masterWeaver", "weaver cloth roll"),
    ("jesuitMissionary", "prayer book"),
    ("firebrandPreacher", "prayer book"),
    ("indianConvert", "prayer book"),
    ("elderStatesman", "statesman scroll"),
    ("seasonedScout", "scout spyglass"),
    ("pettyCriminal", "prisoner wrist chain"),
    ("indenturedServant", "worn coat patch"),
    ("undead", "tattered coat hem"),
    ("revenger", "tattered coat hem"),
):
    common.reset()
    figures.build_figure({"params": {"profession": profession, "role": "civilian"}},
                         common.View(18), random.Random(1))
    assert identifying in names(), (profession, identifying)

for role, identifying in (("missionary", "prayer book"), ("pioneer", "pioneer shovel blade")):
    common.reset()
    figures.build_figure({"params": {"profession": role, "role": role}}, common.View(18), random.Random(1))
    assert identifying in names(), role

for good, identifying in (
    ("bells", "bell lip"), ("cigars", "cigar box"), ("crosses", "crosses base"),
    ("fish", "fish eye"), ("food", "bread loaf"), ("furs", "fur bundle tie"),
    ("hammers", "hammer head"), ("horses", "horse head"), ("lumber", "log cut end"),
    ("meat", "ham bone"), ("muskets", "musket bayonet"), ("ore", "iron ore seam"),
    ("rum", "barrel tap"), ("silver", "silver ingot"), ("sugar", "sugar crystals"),
    ("tools", "wrench jaw"), ("tradeGoods", "trade pottery jar"),
):
    common.reset()
    items.build_goods({"params": {"type": good}}, common.View(35), random.Random(1))
    assert identifying in names(), (good, identifying)

for wagon, identifying in (("wagonTrain", "wagon bonnet"), ("treasureTrain", "treasure chest"),
                           ("artillery", "cannon barrel"), ("damagedArtillery", "broken carriage")):
    common.reset()
    vehicles.build_wagon({"params": {"type": wagon}}, common.View(24), random.Random(1))
    assert identifying in names(), (wagon, identifying)
    if wagon != "wagonTrain":
        assert "wagon bonnet" not in names(), wagon
    assert "wooden wheel rim" in names()
    wheels = objects("wooden wheel rim")
    if wagon == "damagedArtillery":
        assert all(vertex.co.y < 0 for vertex in wheels[0].data.vertices)
        assert len(wheels[0].data.polygons) < len(wheels[1].data.polygons) * 0.7
        assert len(objects("wheel spoke")) == 12
        assert {"broken wheel spoke", "fallen wheel fragment", "splintered wheel fragment"} <= names()
    elif wagon == "artillery":
        assert len(wheels[0].data.polygons) == len(wheels[1].data.polygons)
        assert len(objects("wheel spoke")) == 16
    elif wagon == "treasureTrain":
        assert {
            "arched treasure lid", "chest front band", "chest lid band", "chest lock", "chest keyhole",
        } <= names()
        bpy.context.view_layer.update()
        chest = bounds(objects("treasure chest")[0])
        bed = bounds(objects("wagon bed")[0])
        assert chest[0][1] - chest[0][0] >= (bed[0][1] - bed[0][0]) * 0.8
        assert bounds(objects("arched treasure lid")[0])[2][1] > chest[2][1]

hulls = {}
stern_tops = {}
for ship, identifying, mast_count, square_count, lateen_count in (
    ("caravel", "lateen sail", 2, 0, 2),
    ("merchantman", "merchant cargo crate", 3, 4, 0),
    ("galleon", "galleon stern gallery", 4, 3, 2),
    ("frigate", "deck cannon", 3, 7, 0),
    ("manOWar", "lower gun port", 3, 7, 0),
    ("privateer", "deck cannon", 2, 4, 0),
    ("flyingDutchman", "ghost pennant", 3, 5, 0),
):
    common.reset()
    vehicles.build_ship({"params": {"type": ship}}, common.View(22), random.Random(1))
    assert identifying in names(), (ship, identifying)
    assert len(objects("mast")) == mast_count, ship
    assert "sail stitched seam" in names()
    bpy.context.view_layer.update()
    hulls[ship] = bounds(objects("caravel hull")[0])
    stern_tops[ship] = bounds(objects("stern castle")[0])[2][1]
    assert len(objects("square sail")) == len(objects("square yard")) == square_count, ship
    assert len(objects("lateen sail")) == len(objects("lateen yard")) == lateen_count, ship
    for kind in ("square sail", "lateen sail", "square yard"):
        for obj in objects(kind):
            box = bounds(obj)
            x_span, y_span = box[0][1] - box[0][0], box[1][1] - box[1][0]
            assert (x_span > y_span * 4 if kind == "lateen sail" else y_span > x_span * 4), ship
    if ship == "flyingDutchman":
        assert all(len(sail.data.polygons) <= 50 for sail in objects("square sail"))
    if ship in {"frigate", "manOWar", "privateer"}:
        assert len(objects("gun port")) == 8
        assert len(objects("lower gun port")) == (8 if ship == "manOWar" else 0)

assert hulls["merchantman"][1][1] > hulls["privateer"][1][1]
assert stern_tops["galleon"] > stern_tops["frigate"] + 0.3
print("Validated figure, mounted-role, goods and vehicle geometry", flush=True)
