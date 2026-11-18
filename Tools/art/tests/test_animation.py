import zipfile
from pathlib import Path

from PIL import Image

from novaloria_art.animation import write_animations
from novaloria_art.manifest import Manifest


def test_animation_writer_creates_freecol_sza_archive(tmp_path: Path):
    staging = tmp_path / "staging"
    sprite = staging / "resources/images/units/soldier/soldier.png"
    sprite.parent.mkdir(parents=True)
    Image.new("RGBA", (32, 64), (180, 90, 45, 255)).save(sprite)
    manifest = Manifest(data_dir=tmp_path)
    manifest.entries = {
        "animation.unit.model.unit.freeColonist.soldier.attack.e":
            "resources/images/units/soldier/soldier-attack-right.sza"
    }
    manifest.families = {"animation.unit.model.unit.freeColonist.soldier.attack.e": "animation"}

    written = write_animations(manifest, staging)

    archive_path = staging / written[0]
    with zipfile.ZipFile(archive_path) as archive:
        names = archive.namelist()
        descriptor = archive.read("animation.txt").decode("utf-8")
        assert names[0] == "animation.txt"
        assert len(names) == 7
        assert descriptor.splitlines()[0] == "frame-00.png (100ms)"
        for name in names[1:]:
            with Image.open(archive.open(name)) as frame:
                assert frame.size == (32, 64)
