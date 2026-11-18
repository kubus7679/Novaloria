from pathlib import Path

import pytest
from PIL import Image

from novaloria_art.artspec import PROTOTYPE, SPECS, full_specs
from novaloria_art.manifest import (
    canonical_path,
    classify,
    hires_name,
    load_manifest,
    sibling_variations,
    variation_name,
)

FREECOL = Path(__file__).resolve().parents[4] / "freecol"


def _png(path: Path, size: tuple[int, int], box: tuple[int, int, int, int] | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    if box:
        image.paste((200, 100, 50, 255), box)
    image.save(path)


@pytest.mark.parametrize(
    ("key", "family"),
    [
        ("image.tile.model.tile.plains.center", "tile"),
        ("image.tile.model.tile.unexplored.center", None),
        ("image.tile.model.tile.beach.edge12", "beach"),
        ("image.tile.model.improvement.river.s1020", "river"),
        ("image.tileforest.model.tile.mixedForest.s0101", "forest"),
        ("image.tileoverlay.model.tile.hills", "overlay"),
        ("image.unit.model.unit.freeColonist.soldier", "unit"),
        ("image.tileitem.model.settlement.colony.small.stockade.dutch", "settlement"),
        ("image.buildingicon.model.building.townHall.english", "building"),
        ("image.icon.model.goods.food", "goods"),
        ("image.flavor.model.foundingFather.adamSmith", None),
        ("image.miscicon.model.nation.dutch", None),
        ("image.tile.unitSelect", None),
    ],
)
def test_classifies_resource_families(key, family):
    assert classify(key) == family


def test_nation_variants_share_one_style():
    assert canonical_path("resources/images/settlements/small_fort.dutch.png") == (
        "resources/images/settlements/small_fort.png"
    )
    assert canonical_path("resources/images/buildings/townhall-english.png") == (
        "resources/images/buildings/townhall.png"
    )
    assert canonical_path("resources/images/buildings/outside-bg-fortress-dutch.png") == (
        "resources/images/buildings/outside-bg-fortress.png"
    )
    assert canonical_path("resources/images/buildings/outside-bg-fort.png") == (
        "resources/images/buildings/outside-bg-fort.png"
    )


def test_sibling_names_follow_freecol_rules():
    assert hires_name("a/center0.png") == "a/center0.size2.png"
    assert variation_name("a/center0.png", 2) == "a/center2.png"
    names = ["t/center0.png", "t/center1.png", "t/center12.png", "t/center123.png", "t/center0.size2.png"]
    assert sibling_variations("t/center0.png", names) == ["t/center1.png", "t/center12.png"]
    assert sibling_variations("f/mixed0101.png", ["f/mixed0101.png", "f/mixed.png", "f/mixed1100.png"]) == []


def test_manifest_reads_sizes_aliases_and_siblings(tmp_path):
    data = tmp_path / "data" / "default"
    _png(data / "resources/images/terrain/ocean/center0.png", (128, 64), (0, 0, 128, 64))
    _png(data / "resources/images/terrain/ocean/center02.png", (128, 64))
    _png(data / "resources/images/terrain/ocean/center0.size9.png", (256, 128))
    _png(data / "resources/images/units/civilian/freeColonist.png", (33, 64), (5, 3, 28, 64))
    (data / "resources.properties").write_text(
        "image.tile.model.tile.ocean.center=resources/images/terrain/ocean/center0.png\n"
        "image.tile.model.tile.lake.center=resource:image.tile.model.tile.ocean.center\n"
        "image.unit.model.unit.freeColonist=resources/images/units/civilian/freeColonist.png\n"
        "image.flavor.model.foundingFather.adamSmith=resources/images/x.jpg\n",
        encoding="latin-1",
    )
    manifest = load_manifest(tmp_path)
    assert set(manifest.entries) == {
        "image.tile.model.tile.ocean.center",
        "image.tile.model.tile.lake.center",
        "image.unit.model.unit.freeColonist",
    }
    ocean = manifest.images["resources/images/terrain/ocean/center0.png"]
    assert (ocean.width, ocean.height) == (128, 64)
    assert ocean.variations == ("resources/images/terrain/ocean/center02.png",)
    assert ocean.hires == ("resources/images/terrain/ocean/center0.size9.png",)
    colonist = manifest.images["resources/images/units/civilian/freeColonist.png"]
    assert colonist.bbox == (5, 3, 28, 64)


@pytest.mark.skipif(
    not (FREECOL / "data/default/resources.properties").is_file(), reason="FreeCol tree missing"
)
def test_real_freecol_tree_covers_all_specified_images():
    manifest = load_manifest(FREECOL)
    counts = manifest.family_counts()
    assert counts["forest"] == 160
    assert counts["river"] == 81
    assert counts["goods"] == 22
    assert all(path in manifest.images for path in SPECS)


@pytest.mark.skipif(
    not (FREECOL / "data/default/resources.properties").is_file(), reason="FreeCol tree missing"
)
def test_full_specs_cover_all_concrete_supported_image_paths():
    manifest = load_manifest(FREECOL)
    specs = full_specs(manifest)
    expected = set()
    for key, value in manifest.entries.items():
        if manifest.families[key] == "animation" or value.startswith("resource:"):
            continue
        path = canonical_path(value)
        if path not in manifest.images:
            path = value
        if path in manifest.images:
            expected.add(path)
    assert specs.keys() >= PROTOTYPE
    assert expected <= specs.keys()
    assert {"river", "beach", "delta", "plow", "clouds", "buildingBackground"} <= {
        spec.kit for spec in specs.values()
    }
    assert all(path in manifest.images for path in specs)
