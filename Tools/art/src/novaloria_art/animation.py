"""Build FreeCol Simple Zipped Animation archives from generated unit sprites."""

from __future__ import annotations

import io
import math
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw

from .artspec import FIGURE_CANVAS
from .manifest import Manifest

# Projected musket muzzles in the shared figure canvas.
FIGURE_ATTACK_MUZZLES = {
    "soldier": (35.67, 31.91),
    "dragoon": (48.83, 12.85),
}

SHIP_ANIMATION_OVERRIDES = {
    "animation.unit.model.unit.manOWar.attack.sw": (
        "resources/images/units/ship/manOWar.png",
        "resources/images/units/ship/manOWar-attack.sza",
    ),
    "animation.unit.model.unit.flyingDutchman.attack.sw": (
        "resources/images/units/ship/flyingDutchman.png",
        "resources/images/units/ship/flyingDutchman-attack.sza",
    ),
}


def _animation_frames(sprite_path: Path, attack: bool) -> list[bytes]:
    with Image.open(sprite_path) as source_file:
        source = source_file.convert("RGBA")
    frames: list[bytes] = []
    angles = (-5, -2, 2, 6, 1, -4)
    width, height = source.size
    muzzle = FIGURE_ATTACK_MUZZLES.get(sprite_path.parent.name) if source.size == FIGURE_CANVAS else None
    rotation_center = (width * 0.48, height * 0.55)
    for index, angle in enumerate(angles):
        frame = source.rotate(angle, resample=Image.Resampling.BICUBIC, center=rotation_center)
        shifted = Image.new("RGBA", source.size)
        shift = round((index - 2) * width * 0.035)
        shifted.alpha_composite(frame, dest=(shift, 0))
        if attack:
            draw = ImageDraw.Draw(shifted)
            if muzzle is None:
                x = round(width * (0.72 + (index % 2) * 0.05))
                y = round(height * (0.30 + (index % 3) * 0.04))
                radius = max(2, round(min(width, height) * (0.07 if index in (2, 3) else 0.035)))
            else:
                dx, dy = muzzle[0] - rotation_center[0], muzzle[1] - rotation_center[1]
                sine, cosine = math.sin(math.radians(angle)), math.cos(math.radians(angle))
                x = round(rotation_center[0] + cosine * dx + sine * dy) + shift
                y = round(rotation_center[1] - sine * dx + cosine * dy)
                radius = max(2, round(min(width, height) * (0.045 if index in (2, 3) else 0.025)))
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(250, 220, 127, 235))
            draw.line(
                (x - radius * 2, y, x + radius * 2, y), fill=(255, 242, 194, 240), width=max(1, radius // 3)
            )
        output = io.BytesIO()
        shifted.save(output, format="PNG", optimize=True)
        frames.append(output.getvalue())
    return frames


def _write_animation(sprite_path: Path, target: Path) -> None:
    frames = _animation_frames(sprite_path, attack="attack" in target.stem)
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        descriptor = "\n".join(f"frame-{index:02}.png (100ms)" for index in range(len(frames))) + "\n"
        archive.writestr("animation.txt", descriptor)
        for index, frame in enumerate(frames):
            archive.writestr(f"frame-{index:02}.png", frame)


def write_animations(manifest: Manifest, staging: Path, selected: set[str] | None = None) -> list[str]:
    paths = sorted(
        {
            value
            for key, value in manifest.entries.items()
            if manifest.families.get(key) == "animation" and not value.startswith("resource:")
        }
    )
    written = []
    for path in paths:
        relative = Path(path.removeprefix("resources/images/"))
        animation_name = relative.name.removesuffix(".sza")
        unit_name = animation_name.split("-attack", 1)[0]
        sprite_root = staging / "resources/images" / relative.parent
        sprite_path = sprite_root / f"{unit_name}.png"
        if not sprite_path.is_file():
            fallback = {
                "dragoon": "dragoon.png",
                "ship": "frigate.png",
                "soldier": "soldier.png",
                "wagon": "artillery.png",
            }.get(relative.parent.name)
            if fallback is not None:
                sprite_path = sprite_root / fallback
        if not sprite_path.is_file():
            continue
        if selected is not None and sprite_path.relative_to(staging).as_posix() not in selected:
            continue
        _write_animation(sprite_path, staging / path)
        written.append(path)
    for key, (sprite, path) in SHIP_ANIMATION_OVERRIDES.items():
        if key not in manifest.entries or manifest.families.get(key) != "animation":
            continue
        if selected is not None and sprite not in selected:
            continue
        sprite_path = staging / sprite
        if not sprite_path.is_file():
            raise FileNotFoundError(f"Cannot create {key}: missing sprite {sprite_path}")
        _write_animation(sprite_path, staging / path)
        written.append(path)
    return written
