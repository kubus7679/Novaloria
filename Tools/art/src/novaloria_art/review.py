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


def preview_sheet(
    pairs: list[tuple[str, Path, Path]],
    output: Path,
    headings: tuple[str, str] = ("Aktueller Atlas", "Vorschlag"),
) -> None:
    """Compare two sets of sprites enlarged and at native size."""
    rows = []
    native_width = 72
    for label, old, new in pairs:
        images = []
        for file in (old, new):
            with Image.open(file) as image:
                sprite = image.convert("RGBA")
            hires = Path(hires_name(str(file)))
            enlarged = sprite
            if hires.is_file():
                with Image.open(hires) as image:
                    if image.size == (sprite.width * 2, sprite.height * 2):
                        enlarged = image.convert("RGBA")
            images.append((sprite, enlarged))
            native_width = max(native_width, sprite.width)
        rows.append((label, images, max(180, *(sprite.height + 40 for sprite, _ in images))))
    column_width = 230 + native_width + 25
    width = 255 + 2 * column_width
    sheet = Image.new("RGBA", (width, 52 + sum(row[2] for row in rows)), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    font = _font(16)
    small = _font(13)
    draw.text((280, 15), headings[0], fill=INK, font=font)
    draw.text((280 + column_width, 15), headings[1], fill=INK, font=font)
    top = 52
    for label, images, height in rows:
        draw.line((10, top, width - 10, top), fill=(164, 151, 123, 255), width=1)
        draw.text((15, top + 65), label, fill=INK, font=small)
        for column, (sprite, enlarged) in enumerate(images):
            scale = min(4.0, 180 / sprite.width, 145 / sprite.height)
            size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
            thumb = enlarged.resize(size, Image.Resampling.LANCZOS)
            left = 255 + column * column_width
            sheet.alpha_composite(thumb, (left + (180 - thumb.width) // 2,
                                          top + (height - thumb.height) // 2))
            native_x = left + 210 + (native_width - sprite.width) // 2
            sheet.alpha_composite(sprite, (native_x, top + (height - sprite.height) // 2))
            draw.text((left + 210 + native_width // 2 - 10, top + height - 23), "1:1", fill=INK, font=small)
        top += height
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
RIVER_TILES = {(4, 3), (4, 4), (4, 5), (4, 6), (4, 7), (5, 8)}
FIELDS = {(3, 4), (2, 5), (3, 7)}


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

    def is_land(x, y):
        return 0 <= y < len(rows) and 0 <= x < len(rows[y]) and rows[y][x][0] != "O"

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
            east = 1 if y % 2 else 0
            neighbors = [(x + east, y - 1), (x + east, y + 1),
                         (x + east - 1, y + 1), (x + east - 1, y - 1)]
            if cell[0] == "O":
                edges = [is_land(*point) for point in neighbors]
                corners = [(x, y - 2), (x + 1, y), (x, y + 2), (x - 1, y)]
                corner_bits = sum(
                    1 << i for i, point in enumerate(corners)
                    if is_land(*point) and not edges[i] and not edges[(i - 1) % 4]
                )
                for kind, bits in (("edge", sum(1 << i for i, edge in enumerate(edges) if edge)),
                                   ("corner", corner_bits)):
                    if bits and (beach := load(f"terrain/beach/{kind}{bits}_0.png")) is not None:
                        canvas.alpha_composite(beach.resize((tile_w, tile_h)), dest=(left, top))
            if (x, y) in FIELDS and (field := load("misc/plowed.png")) is not None:
                canvas.alpha_composite(field.resize((tile_w, tile_h)), dest=(left, top))
            if (x, y) in RIVER_TILES:
                index = sum(3 ** i for i, point in enumerate(neighbors) if point in RIVER_TILES)
                if (river := load(f"river/river{index}.png")) is not None:
                    canvas.alpha_composite(river.resize((tile_w, tile_h)), dest=(left, top))
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
