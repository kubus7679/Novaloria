import zipfile
from io import BytesIO
from pathlib import Path

import numpy as np
import pytest
from PIL import Image, ImageDraw

from novaloria_art.animation import (
    FIGURE_ATTACK_MUZZLES,
    SHIP_ANIMATION_OVERRIDES,
    _animation_frames,
    write_animations,
)
from novaloria_art.artspec import FIGURE_CANVAS
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


def test_partial_animation_rebuild_only_updates_selected_sprites(tmp_path: Path):
    staging = tmp_path / "staging"
    soldier = "resources/images/units/soldier/soldier.png"
    ship = "resources/images/units/ship/frigate.png"
    for path in (soldier, ship):
        target = staging / path
        target.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", (32, 64), (180, 90, 45, 255)).save(target)
    soldier_animation = "resources/images/units/soldier/soldier-attack-right.sza"
    ship_animation = "resources/images/units/ship/frigate-attack.sza"
    (staging / soldier_animation).write_bytes(b"existing soldier animation")
    manifest = Manifest(data_dir=tmp_path)
    manifest.entries = {"soldier": soldier_animation, "ship": ship_animation}
    manifest.families = {"soldier": "animation", "ship": "animation"}

    written = write_animations(manifest, staging, {ship})

    assert written == [ship_animation]
    assert (staging / soldier_animation).read_bytes() == b"existing soldier animation"
    with zipfile.ZipFile(staging / ship_animation) as archive:
        assert archive.testzip() is None


@pytest.mark.parametrize("role", ["soldier", "dragoon"])
def test_figure_attack_flash_tracks_the_rotated_muzzle(tmp_path: Path, role: str):
    sprite = tmp_path / role / f"{role}.png"
    sprite.parent.mkdir()
    image = Image.new("RGBA", FIGURE_CANVAS)
    x, y = FIGURE_ATTACK_MUZZLES[role]
    ImageDraw.Draw(image).ellipse((x - 3, y - 3, x + 3, y + 3), fill=(10, 30, 240, 255))
    image.save(sprite)

    plain = _animation_frames(sprite, attack=False)
    attack = _animation_frames(sprite, attack=True)
    for ordinary_frame, attack_frame in zip(plain, attack, strict=True):
        with Image.open(BytesIO(ordinary_frame)) as frame:
            normal_pixels = np.asarray(frame.convert("RGBA"))
        with Image.open(BytesIO(attack_frame)) as frame:
            attack_pixels = np.asarray(frame.convert("RGBA"))
        marker = (
            (normal_pixels[:, :, 2] > 150)
            & (normal_pixels[:, :, 0] < 100)
            & (normal_pixels[:, :, 3] > 128)
        )
        flash = (
            (attack_pixels[:, :, 0] > 200)
            & (attack_pixels[:, :, 1] > 150)
            & (attack_pixels[:, :, 2] < 210)
            & (attack_pixels[:, :, 3] > 150)
        )
        for marker_axis, flash_axis in zip(np.nonzero(marker), np.nonzero(flash), strict=True):
            assert marker_axis.size and flash_axis.size
            assert abs((marker_axis.min() + marker_axis.max()) / 2
                       - (flash_axis.min() + flash_axis.max()) / 2) <= 1.5


def _ship_manifest(tmp_path: Path) -> Manifest:
    manifest = Manifest(data_dir=tmp_path)
    manifest.entries = {
        "animation.unit.model.unit.frigate.attack.sw": "resources/images/units/ship/frigate-attack.sza",
        "animation.unit.model.unit.manOWar.attack.sw": "resources/images/units/ship/frigate-attack.sza",
        "animation.unit.model.unit.privateer.attack.sw": "resources/images/units/ship/privateer-attack.sza",
        "animation.unit.model.unit.flyingDutchman.attack.sw": (
            "resources/images/units/ship/privateer-attack.sza"
        ),
    }
    manifest.families = {key: "animation" for key in manifest.entries}
    return manifest


def test_shared_ship_animations_use_the_correct_ship_sprites(tmp_path: Path):
    staging = tmp_path / "staging"
    ships = {
        "frigate": ((24, 28), (180, 90, 45, 255)),
        "manOWar": ((26, 30), (60, 70, 80, 255)),
        "privateer": ((22, 24), (30, 20, 10, 255)),
        "flyingDutchman": ((20, 26), (50, 160, 90, 255)),
    }
    for ship, (size, color) in ships.items():
        sprite = staging / f"resources/images/units/ship/{ship}.png"
        sprite.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", size, color).save(sprite)

    written = write_animations(_ship_manifest(tmp_path), staging)

    assert set(written) == {
        f"resources/images/units/ship/{ship}-attack.sza" for ship in ships
    }
    for ship, (size, color) in ships.items():
        with zipfile.ZipFile(staging / f"resources/images/units/ship/{ship}-attack.sza") as archive:
            assert archive.testzip() is None
            with Image.open(archive.open("frame-00.png")) as frame:
                assert frame.size == size
                assert frame.getpixel((size[0] // 2, size[1] // 2)) == color


def test_partial_ship_animation_rebuild_preserves_other_ship_archives(tmp_path: Path):
    staging = tmp_path / "staging"
    manowar_sprite, manowar_animation = SHIP_ANIMATION_OVERRIDES[
        "animation.unit.model.unit.manOWar.attack.sw"
    ]
    sprite = staging / manowar_sprite
    sprite.parent.mkdir(parents=True)
    Image.new("RGBA", (26, 30), (60, 70, 80, 255)).save(sprite)
    frigate_animation = staging / "resources/images/units/ship/frigate-attack.sza"
    frigate_animation.write_bytes(b"existing frigate animation")
    ghost_animation = staging / SHIP_ANIMATION_OVERRIDES[
        "animation.unit.model.unit.flyingDutchman.attack.sw"
    ][1]
    ghost_animation.write_bytes(b"existing ghost animation")

    written = write_animations(_ship_manifest(tmp_path), staging, {manowar_sprite})

    assert written == [manowar_animation]
    assert frigate_animation.read_bytes() == b"existing frigate animation"
    assert ghost_animation.read_bytes() == b"existing ghost animation"
    with zipfile.ZipFile(staging / manowar_animation) as archive:
        assert archive.testzip() is None


def test_selected_ship_animation_requires_its_sprite(tmp_path: Path):
    sprite, _ = SHIP_ANIMATION_OVERRIDES["animation.unit.model.unit.manOWar.attack.sw"]
    with pytest.raises(FileNotFoundError, match="missing sprite"):
        write_animations(_ship_manifest(tmp_path), tmp_path / "staging", {sprite})
