"""Build FreeCol Simple Zipped Animation archives from generated unit sprites."""

from __future__ import annotations

import io
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw

from .manifest import Manifest


def _animation_frames(sprite_path: Path, attack: bool) -> list[bytes]:
    with Image.open(sprite_path) as source_file:
        source = source_file.convert("RGBA")
    frames: list[bytes] = []
    angles = (-5, -2, 2, 6, 1, -4)
    width, height = source.size
    for index, angle in enumerate(angles):
        frame = source.rotate(angle, resample=Image.Resampling.BICUBIC, center=(width * 0.48, height * 0.55))
        shifted = Image.new("RGBA", source.size)
        shifted.alpha_composite(frame, dest=(round((index - 2) * width * 0.035), 0))
        if attack:
            draw = ImageDraw.Draw(shifted)
            x = round(width * (0.72 + (index % 2) * 0.05))
            y = round(height * (0.30 + (index % 3) * 0.04))
            radius = max(2, round(min(width, height) * (0.07 if index in (2, 3) else 0.035)))
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(250, 220, 127, 235))
            draw.line(
                (x - radius * 2, y, x + radius * 2, y), fill=(255, 242, 194, 240), width=max(1, radius // 3)
            )
        output = io.BytesIO()
        shifted.save(output, format="PNG", optimize=True)
        frames.append(output.getvalue())
    return frames


def write_animations(manifest: Manifest, staging: Path) -> list[str]:
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
        frames = _animation_frames(sprite_path, attack="attack" in animation_name)
        target = staging / path
        target.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            descriptor = "\n".join(f"frame-{index:02}.png (100ms)" for index in range(len(frames))) + "\n"
            archive.writestr("animation.txt", descriptor)
            for index, frame in enumerate(frames):
                archive.writestr(f"frame-{index:02}.png", frame)
        written.append(path)
    return written
