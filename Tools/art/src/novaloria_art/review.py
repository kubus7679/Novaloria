"""Review artefacts: original/new comparison sheet and a synthetic map excerpt."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from .manifest import hires_name

BACKGROUND = (206, 197, 170, 255)
INK = (40, 32, 24, 255)


def _font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def _fit(image: Image.Image, box: tuple[int, int]) -> Image.Image:
    scale = min(box[0] / image.width, box[1] / image.height, 4.0)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.resize(size, Image.Resampling.LANCZOS)


def contact_sheet(pairs: list[tuple[str, Path, Path]], output: Path) -> None:
    """One row per asset: label, original FreeCol image, new image (both enlarged)."""
    cell = (220, 150)
    label_width = 260
    font = _font(15)
    sheet = Image.new("RGBA", (label_width + 2 * cell[0] + 40, 48 + len(pairs) * (cell[1] + 10)), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    draw.text((label_width, 14), "FreeCol original", fill=INK, font=font)
    draw.text((label_width + cell[0] + 20, 14), "Novaloria Atlas", fill=INK, font=font)
    for row, (label, original, new) in enumerate(pairs):
        top = 48 + row * (cell[1] + 10)
        draw.text((12, top + cell[1] // 2 - 8), label, fill=INK, font=font)
        for column, file in enumerate((original, new)):
            if not file.is_file():
                continue
            with Image.open(file) as image:
                thumb = _fit(image.convert("RGBA"), cell)
            left = label_width + column * (cell[0] + 20) + (cell[0] - thumb.width) // 2
            sheet.alpha_composite(thumb, dest=(left, top + (cell[1] - thumb.height) // 2))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)


# Synthetic excerpt in FreeCol's staggered layout; values are terrain, overlay and item keys.
MAP_ROWS = [
    "O O O O O O O",
    "O O O O O O O",
    "O O D D P P O",
    "O D D Pm P G O",
    "O O Ph P G G O",
    "O O P P1 G Gc O",
    "O T Tc P G2 G O",
    "O T A Pf R R O",
    "O O A Tc Pf M O",
    "O O O O Pm O O",
    "O O O O O O O",
]

TERRAIN = {
    "O": "terrain/ocean/center0.png",
    "P": "terrain/plains/center0.png",
    "G": "terrain/grassland/center0.png",
    "R": "terrain/prairie/center0.png",
    "D": "terrain/desert/center0.png",
    "T": "terrain/tundra/center0.png",
    "M": "terrain/marsh/center0.png",
    "A": "terrain/arctic/center0.png",
}
DECOR = {
    "m": ("overlay", "forest/mixed/mixed.png"),
    "c": ("overlay", "forest/conifer/conifer.png"),
    "h": ("overlay", "terrain/hills/hills0.png"),
    "f": ("overlay", "terrain/mountains/mountains0.png"),
    "1": ("settlement", "settlements/small.png"),
    "2": ("settlement", "settlements/medium.png"),
}
UNITS = {
    (2, 5): "units/civilian/freeColonist.png",
    (5, 4): "units/soldier/soldier.png",
    (5, 6): "units/dragoon/dragoon.png",
    (5, 7): "units/wagon/wagonTrain.png",
    (1, 4): "units/ship/caravel.png",
}
ITEMS = {(4, 2): "bonus/grain.png", (4, 3): "misc/lostCityRumour.png"}


def map_excerpt(image_root: Path, output: Path, scale: int, hires: bool) -> None:
    """Compose a small map from the given image tree to judge the art in context."""
    tile_w, tile_h = 128 * scale, 64 * scale

    def load(relative: str) -> Image.Image | None:
        path = image_root / "resources/images" / relative
        factor = scale
        if hires and (candidate := Path(hires_name(str(path)))).is_file():
            path, factor = candidate, 1
        if not path.is_file():
            return None
        with Image.open(path) as image:
            loaded = image.convert("RGBA")
        if factor != 1:
            loaded = loaded.resize((loaded.width * factor, loaded.height * factor), Image.Resampling.LANCZOS)
        return loaded

    rows = [row.split() for row in MAP_ROWS]
    columns = max(len(row) for row in rows)
    canvas = Image.new(
        "RGBA",
        (columns * tile_w + tile_w // 2, (len(rows) + 3) * tile_h // 2),
        (20, 24, 30, 255),
    )
    for y, row in enumerate(rows):
        for x, cell in enumerate(row):
            left = x * tile_w + (tile_w // 2 if y % 2 else 0)
            top = y * tile_h // 2 + tile_h
            base = load(TERRAIN[cell[0]])
            if base is not None:
                canvas.alpha_composite(base.resize((tile_w, tile_h)), dest=(left, top))
    for y, row in enumerate(rows):
        for x, cell in enumerate(row):
            left = x * tile_w + (tile_w // 2 if y % 2 else 0)
            top = y * tile_h // 2 + tile_h
            for flag in cell[1:]:
                kind, relative = DECOR[flag]
                image = load(relative)
                if image is None:
                    continue
                if kind == "overlay":
                    height = round(tile_w * image.height / image.width)
                    canvas.alpha_composite(image.resize((tile_w, height)), dest=(left, top + tile_h - height))
                else:
                    canvas.alpha_composite(
                        image,
                        dest=(left + (tile_w - image.width) // 2, top + tile_h // 2 - image.height * 2 // 3),
                    )
            for placements, anchor in ((ITEMS, 0.5), (UNITS, 0.85)):
                relative = placements.get((x, y))
                if relative is None:
                    continue
                image = load(relative)
                if image is not None:
                    dest = (left + (tile_w - image.width) // 2, top + round(tile_h * anchor) - image.height)
                    canvas.alpha_composite(image, dest=dest)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)
