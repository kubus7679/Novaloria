import zipfile
from pathlib import Path

from PIL import Image

from novaloria_art.manifest import Manifest, sibling_variations
from novaloria_art.package import resource_lines, write_mod


def _manifest(tmp_path: Path) -> Manifest:
    manifest = Manifest(data_dir=tmp_path)
    manifest.entries = {
        "image.tile.model.tile.ocean.center": "resources/images/terrain/ocean/center0.png",
        "image.tile.model.tile.lake.center": "resource:image.tile.model.tile.ocean.center",
        "image.tile.model.tile.swamp.center": "resources/images/terrain/swamp/center0.png",
        "image.tile.model.tile.marsh.center": "resource:image.tile.model.tile.swamp.center",
        "image.tileitem.model.settlement.colony.small": "resources/images/settlements/small.png",
        "image.tileitem.model.settlement.colony.small.dutch": "resources/images/settlements/small.dutch.png",
        "animation.unit.model.unit.freeColonist.soldier.attack.e": (
            "resources/images/units/soldier/attack.sza"
        ),
    }
    return manifest


def test_lines_cover_produced_images_nation_variants_and_resolvable_aliases(tmp_path):
    produced = {
        "resources/images/terrain/ocean/center0.png",
        "resources/images/settlements/small.png",
        "resources/images/units/soldier/attack.sza",
    }
    lines = resource_lines(_manifest(tmp_path), produced)
    assert lines == [
        "image.tile.model.tile.ocean.center=resources/images/terrain/ocean/center0.png",
        "image.tileitem.model.settlement.colony.small=resources/images/settlements/small.png",
        "image.tileitem.model.settlement.colony.small.dutch=resources/images/settlements/small.png",
        "animation.unit.model.unit.freeColonist.soldier.attack.e=resources/images/units/soldier/attack.sza",
        "image.tile.model.tile.lake.center=resource:image.tile.model.tile.ocean.center",
    ]


def test_written_mod_is_installable(tmp_path):
    staging = tmp_path / "staging"
    for relative, size in (
        ("resources/images/terrain/ocean/center0.png", (128, 64)),
        ("resources/images/terrain/ocean/center0.size2.png", (256, 128)),
        ("resources/images/settlements/small.png", (53, 37)),
    ):
        (staging / relative).parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", size).save(staging / relative)
    license_file = tmp_path / "COPYING.src"
    license_file.write_text("GPL", encoding="utf-8")
    mod_dir = tmp_path / "NovaloriaAtlas"
    archive = tmp_path / "NovaloriaAtlas.zip"
    lines = write_mod(_manifest(tmp_path), staging, mod_dir, license_file, archive)
    assert len(lines) == 4
    assert (mod_dir / "mod.xml").read_text(encoding="utf-8") == '<mod id="novaloria-atlas"/>\n'
    assert "license=GPL" in (mod_dir / "FreeColMessages.properties").read_text(encoding="utf-8")
    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
    assert names[0] == "mod.xml"
    assert "resources/images/terrain/ocean/center0.size2.png" in names
    assert {"COPYING", "CREDITS.txt", "resources.properties"} <= set(names)
    animation = staging / "resources/images/units/soldier/attack.sza"
    animation.parent.mkdir(parents=True, exist_ok=True)
    animation.write_bytes(b"sza")
    lines = write_mod(_manifest(tmp_path), staging, mod_dir, license_file, archive)
    assert any(line.endswith("=resources/images/units/soldier/attack.sza") for line in lines)
    with zipfile.ZipFile(archive) as bundle:
        assert "resources/images/units/soldier/attack.sza" in bundle.namelist()
    images = [name for name in names if name.endswith(".png")]
    assert all(sibling_variations(name, images) == [] for name in images)


def test_existing_mod_metadata_is_preserved(tmp_path):
    staging = tmp_path / "staging"
    mod_dir = tmp_path / "NovaloriaAtlas"
    mod_dir.mkdir()
    mod_xml = '<mod id="novaloria-atlas" version="2"/>\n'
    messages = "mod.novaloria-atlas.name=User title\n"
    (mod_dir / "mod.xml").write_text(mod_xml, encoding="utf-8")
    (mod_dir / "FreeColMessages.properties").write_text(messages, encoding="utf-8")
    license_file = tmp_path / "COPYING.src"
    license_file.write_text("GPL", encoding="utf-8")

    write_mod(_manifest(tmp_path), staging, mod_dir, license_file, tmp_path / "atlas.zip")

    assert (mod_dir / "mod.xml").read_text(encoding="utf-8") == mod_xml
    assert (mod_dir / "FreeColMessages.properties").read_text(encoding="utf-8") == messages
