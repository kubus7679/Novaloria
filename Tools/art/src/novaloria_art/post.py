"""Turns supersampled Blender renders into FreeCol-ready images."""

from __future__ import annotations

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

Box = tuple[int, int, int, int]


def diamond_mask(width: int, height: int) -> Image.Image:
    """Binary tile diamond; FreeCol loads ``center`` images with BITMASK transparency."""
    xs = (np.arange(width) + 0.5 - width / 2) / (width / 2)
    ys = (np.arange(height) + 0.5 - height / 2) / (height / 2)
    inside = np.abs(xs)[None, :] + np.abs(ys)[:, None] <= 1.0
    return Image.fromarray(np.where(inside, 255, 0).astype(np.uint8), "L")


def resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Lanczos resize in premultiplied space so transparent pixels do not darken edges."""
    if image.size == size:
        return image.copy()
    return image.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")


def grade(
    image: Image.Image,
    saturation: float = 1.07,
    contrast: float = 1.04,
    sharpen: bool = True,
) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = image.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(saturation)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    if sharpen:
        rgb = rgb.filter(ImageFilter.UnsharpMask(radius=0.7, percent=55, threshold=2))
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def _bbox(alpha: np.ndarray, threshold: int) -> Box | None:
    rows = np.flatnonzero((alpha > threshold).any(axis=1))
    cols = np.flatnonzero((alpha > threshold).any(axis=0))
    if rows.size == 0:
        return None
    return int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1


def finish_tile(raw: Image.Image, canvas: tuple[int, int], factor: int) -> Image.Image:
    size = (canvas[0] * factor, canvas[1] * factor)
    image = resize(raw.convert("RGBA"), size)
    image.putalpha(diamond_mask(*size))
    return grade(image)


def finish_overlay(raw: Image.Image, canvas: tuple[int, int], factor: int) -> Image.Image:
    size = (canvas[0] * factor, canvas[1] * factor)
    image = resize(raw.convert("RGBA"), size)
    alpha = np.asarray(image.getchannel("A")).copy()
    alpha[alpha < 4] = 0
    image.putalpha(Image.fromarray(alpha, "L"))
    return grade(image)


def finish_figure(raw: Image.Image, canvas: tuple[int, int], factor: int) -> Image.Image:
    """Keep the fixed figure frame while tapering faint ground shadows at its edges."""
    image = finish_overlay(raw, canvas, factor)
    width, height = image.size
    xs = np.minimum(np.arange(width), np.arange(width)[::-1])
    ys = np.minimum(np.arange(height), np.arange(height)[::-1])
    fade = np.clip(np.minimum(ys[:, None], xs[None, :]) / (5 * factor), 0.0, 1.0)
    alpha = np.rint(np.asarray(image.getchannel("A")) * fade).astype(np.uint8)
    alpha[alpha < 4] = 0
    image.putalpha(Image.fromarray(alpha, "L"))
    return image


def place_sprite(
    raw: Image.Image,
    canvas: tuple[int, int],
    target: Box | None,
    align: str,
    factor: int,
) -> Image.Image:
    """Scale the rendered subject into the original's footprint so anchoring stays unchanged.

    ``baseline`` matches the original height and keeps the feet on the original baseline,
    ``fit`` fits inside the original box bottom-aligned, ``icon`` fits and centers.
    """
    raw = raw.convert("RGBA")
    alpha = np.asarray(raw.getchannel("A"))
    subject = _bbox(alpha, 128)
    content = _bbox(alpha, 6)
    if subject is None or content is None:
        raise ValueError("render contains no visible subject")
    width, height = canvas[0] * factor, canvas[1] * factor
    tx0, ty0, tx1, ty1 = [value * factor for value in (target or (0, 0, canvas[0], canvas[1]))]
    target_w, target_h = tx1 - tx0, ty1 - ty0
    subject_w, subject_h = subject[2] - subject[0], subject[3] - subject[1]
    if align == "baseline":
        scale = target_h / subject_h
        if subject_w * scale > width:
            scale = width / subject_w
    else:
        scale = min(target_w / subject_w, target_h / subject_h)
    center_x = (tx0 + tx1) / 2
    top = (ty0 + ty1) / 2 - subject_h * scale / 2 if align == "icon" else ty1 - subject_h * scale
    left = center_x - subject_w * scale / 2
    left = min(max(left, 0.0), max(0.0, width - subject_w * scale))
    crop = raw.crop(content)
    scaled = resize(crop, (max(1, round(crop.width * scale)), max(1, round(crop.height * scale))))
    offset = (round(left + (content[0] - subject[0]) * scale), round(top + (content[1] - subject[1]) * scale))
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x0, y0 = max(offset[0], 0), max(offset[1], 0)
    x1, y1 = min(offset[0] + scaled.width, width), min(offset[1] + scaled.height, height)
    if x1 > x0 and y1 > y0:
        visible = scaled.crop((x0 - offset[0], y0 - offset[1], x1 - offset[0], y1 - offset[1]))
        out.alpha_composite(visible, dest=(x0, y0))
    return grade(out)
