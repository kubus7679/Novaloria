import zipfile
from argparse import Namespace
from pathlib import Path

import pytest
from PIL import Image

from novaloria_art import cli
from novaloria_art.artspec import Spec
from novaloria_art.manifest import ImageInfo, Manifest, sibling_variations
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


def test_ship_animation_overrides_are_used_only_when_generated(tmp_path):
    manifest = Manifest(data_dir=tmp_path)
    manifest.entries = {
        "animation.unit.model.unit.frigate.attack.sw": "resources/images/units/ship/frigate-attack.sza",
        "animation.unit.model.unit.manOWar.attack.sw": "resources/images/units/ship/frigate-attack.sza",
        "animation.unit.model.unit.privateer.attack.sw": "resources/images/units/ship/privateer-attack.sza",
        "animation.unit.model.unit.flyingDutchman.attack.sw": (
            "resources/images/units/ship/privateer-attack.sza"
        ),
        "animation.unit.model.unit.ghost.attack.sw": (
            "resource:animation.unit.model.unit.flyingDutchman.attack.sw"
        ),
    }
    frigate = "resources/images/units/ship/frigate-attack.sza"
    privateer = "resources/images/units/ship/privateer-attack.sza"
    manowar = "resources/images/units/ship/manOWar-attack.sza"
    ghost = "resources/images/units/ship/flyingDutchman-attack.sza"

    before = resource_lines(manifest, {frigate, privateer})
    after = resource_lines(manifest, {frigate, privateer, manowar, ghost})

    assert f"animation.unit.model.unit.manOWar.attack.sw={frigate}" in before
    assert f"animation.unit.model.unit.flyingDutchman.attack.sw={privateer}" in before
    assert f"animation.unit.model.unit.manOWar.attack.sw={manowar}" in after
    assert f"animation.unit.model.unit.flyingDutchman.attack.sw={ghost}" in after
    assert f"animation.unit.model.unit.frigate.attack.sw={frigate}" in after
    assert f"animation.unit.model.unit.privateer.attack.sw={privateer}" in after
    assert (
        "animation.unit.model.unit.ghost.attack.sw=resource:animation.unit.model.unit.flyingDutchman.attack.sw"
        in after
    )


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


def test_partial_build_retains_unselected_packaged_resources(tmp_path, monkeypatch):
    freecol = tmp_path / "freecol"
    data = freecol / "data/default"
    paths = [f"resources/images/terrain/{kind}/center0.png" for kind in ("plains", "ocean")]
    for path in paths:
        image = data / path
        image.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", (128, 64), (60, 110, 150, 255)).save(image)
    (data / "resources.properties").write_text("\n".join(
        f"image.tile.model.tile.{kind}.center={path}"
        for kind, path in zip(("plains", "ocean"), paths, strict=True)
    ))
    build = tmp_path / "build"
    mod = tmp_path / "mod"
    unchanged = mod / paths[1]
    unchanged.parent.mkdir(parents=True)
    unchanged.write_bytes((data / paths[1]).read_bytes())
    animation = mod / "resources/images/units/attack.sza"
    animation.parent.mkdir(parents=True)
    animation.write_bytes(b"existing animation")
    raw = build / "raw/terrain-plains-center0.png"
    raw.parent.mkdir(parents=True)
    Image.new("RGBA", (512, 256), (130, 160, 70, 255)).save(raw)
    stale = build / "out" / paths[1]
    stale.parent.mkdir(parents=True)
    Image.new("RGBA", (128, 64), (250, 0, 0, 255)).save(stale)
    orphan = build / "out/resources/images/obsolete.png"
    Image.new("RGBA", (8, 8), (250, 0, 0, 255)).save(orphan)
    license_file = tmp_path / "COPYING"
    license_file.write_text("GPL")
    archive = tmp_path / "mod.zip"
    for key, value in {
        "BUILD": build, "STAGING": build / "out", "MOD_DIR": mod,
        "ARCHIVE": archive, "LICENSE": license_file,
    }.items():
        monkeypatch.setattr(cli, key, value)
    monkeypatch.setattr(cli, "full_specs", lambda _: {
        paths[0]: Spec("terrain", {"type": "plains"}, mode="tile", canvas=(128, 64)),
    })
    monkeypatch.setattr(cli, "_review", lambda *_: None)
    monkeypatch.setattr(
        cli, "write_animations", lambda *_: pytest.fail("Terrain must not rebuild animations")
    )

    cli.build(Namespace(freecol=freecol, only=["plains"], prototype=False, skip_render=True))

    assert unchanged.read_bytes() == (data / paths[1]).read_bytes()
    assert not (mod / "resources/images/obsolete.png").exists()
    assert animation.read_bytes() == b"existing animation"
    assert "model.tile.ocean.center=" in (mod / "resources.properties").read_text()
    with zipfile.ZipFile(archive) as bundle:
        assert paths[0] in bundle.namelist()
        assert paths[1] in bundle.namelist()
        assert animation.relative_to(mod).as_posix() in bundle.namelist()


def test_partial_ship_build_preserves_distinct_attack_animations(tmp_path, monkeypatch):
    freecol = tmp_path / "freecol"
    data = freecol / "data/default"
    root = "resources/images/units/ship"
    paths = {ship: f"{root}/{ship}.png" for ship in ("frigate", "manOWar")}
    for path in paths.values():
        original = data / path
        original.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", (32, 32), (60, 110, 150, 255)).save(original)
    (data / "resources.properties").write_text(
        "\n".join([
            *(f"image.unit.model.unit.{ship}={path}" for ship, path in paths.items()),
            f"animation.unit.model.unit.frigate.attack.sw={root}/frigate-attack.sza",
            f"animation.unit.model.unit.manOWar.attack.sw={root}/frigate-attack.sza",
        ])
    )
    build = tmp_path / "build"
    mod = tmp_path / "mod"
    archive = tmp_path / "mod.zip"
    license_file = tmp_path / "COPYING"
    license_file.write_text("GPL")
    for ship, path in paths.items():
        sprite = mod / path
        sprite.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", (32, 32), (60, 110, 150, 255)).save(sprite)
        raw = build / f"raw/units-ship-{ship}.png"
        raw.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", (128, 128), (130, 160, 70, 255)).save(raw)
    frigate_animation = mod / f"{root}/frigate-attack.sza"
    frigate_animation.write_bytes(b"existing frigate animation")
    for key, value in {
        "BUILD": build, "STAGING": build / "out", "MOD_DIR": mod,
        "ARCHIVE": archive, "LICENSE": license_file,
    }.items():
        monkeypatch.setattr(cli, key, value)
    monkeypatch.setattr(cli, "full_specs", lambda _: {
        path: Spec("ship", {"type": ship}, align="fit") for ship, path in paths.items()
    })
    monkeypatch.setattr(cli, "_review", lambda *_: None)

    cli.build(Namespace(freecol=freecol, only=["manOWar.png"], prototype=False, skip_render=True))

    manowar_animation = mod / f"{root}/manOWar-attack.sza"
    manowar_bytes = manowar_animation.read_bytes()
    assert frigate_animation.read_bytes() == b"existing frigate animation"
    assert f"animation.unit.model.unit.manOWar.attack.sw={root}/manOWar-attack.sza" in (
        mod / "resources.properties"
    ).read_text()

    cli.build(Namespace(freecol=freecol, only=["frigate.png"], prototype=False, skip_render=True))

    assert manowar_animation.read_bytes() == manowar_bytes
    with zipfile.ZipFile(frigate_animation) as generated:
        assert generated.testzip() is None
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.read(f"{root}/manOWar-attack.sza") == manowar_bytes
    assert f"animation.unit.model.unit.manOWar.attack.sw={root}/manOWar-attack.sza" in (
        mod / "resources.properties"
    ).read_text()


def test_preview_is_isolated_and_renders_exact_paths(tmp_path, monkeypatch):
    path = "resources/images/goods/grain.png"
    old = tmp_path / "mod" / path
    old.parent.mkdir(parents=True)
    Image.new("RGBA", (32, 32), (200, 150, 40, 255)).save(old)
    original = old.read_bytes()
    manifest = Manifest(data_dir=tmp_path)
    manifest.images[path] = ImageInfo(path, 32, 32, (0, 0, 32, 32))
    monkeypatch.setattr(cli, "MOD_DIR", tmp_path / "mod")
    monkeypatch.setattr(cli, "STAGING", tmp_path / "staging")
    monkeypatch.setattr(cli, "load_manifest", lambda _: manifest)
    monkeypatch.setattr(cli, "full_specs", lambda _: {path: Spec("goods", {"type": "grain"}, align="icon")})
    monkeypatch.setattr(cli, "write_mod", lambda *_: pytest.fail("Preview must not package the mod"))
    monkeypatch.setattr(cli, "write_animations", lambda *_: pytest.fail("Preview must not create animations"))

    def render(jobs, blender, work_dir, samples):
        assert len(jobs) == 1
        Image.new("RGBA", (64, 64), (220, 180, 70, 255)).save(jobs[0]["output"])
        return work_dir / "blender.log"

    monkeypatch.setattr(cli, "run_blender", render)
    output = tmp_path / "preview"
    args = Namespace(freecol=tmp_path, paths=[path, path], output=output, blender="blender", samples=8)
    cli.preview(args)
    assert old.read_bytes() == original
    assert (output / "comparison.png").is_file()
    assert (output / "out" / path).is_file()
    assert (output / "out/resources/images/goods/grain.size2.png").is_file()
    assert not (tmp_path / "staging").exists()

    args.paths = ["goods/grain"]
    with pytest.raises(ValueError, match="Unknown render paths"):
        cli.preview(args)
    args.paths = [path]
    args.output = tmp_path / "mod"
    with pytest.raises(ValueError, match="separate"):
        cli.preview(args)
