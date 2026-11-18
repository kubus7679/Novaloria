"""Inventory of the FreeCol default image resources a graphics mod has to replace."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image

from .properties import read_properties

RESOURCE_PREFIX = "resource:"

# Families the mod replaces; every other FreeCol resource key stays untouched.
FAMILIES: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("tile", re.compile(r"image\.tile\.model\.tile\.(?!unexplored\.)[A-Za-z]+\.center")),
    ("beach", re.compile(r"image\.tile\.model\.tile\.beach(\.(edge|corner)\d+)?")),
    ("delta", re.compile(r"image\.tile\.model\.tile\.delta\.[A-Z]+\.(large|small)")),
    ("river", re.compile(r"image\.tile\.model\.improvement\.river\.s[0-2]{4}")),
    ("riverTexture", re.compile(r"image\.tile\.river\.(water|pebbles)")),
    ("plow", re.compile(r"image\.tile\.model\.improvement\.plow")),
    ("overlay", re.compile(r"image\.tileoverlay\.model\.tile\.[A-Za-z]+")),
    ("forest", re.compile(r"image\.tileforest\.model\.tile\.[A-Za-z]+(\.[a-z0-9]+)?")),
    ("clouds", re.compile(r"image\.abovetile\.model\.tile\.[A-Za-z]+")),
    ("bonus", re.compile(r"image\.tileitem\.model\.resource\.[A-Za-z]+")),
    ("lcr", re.compile(r"image\.tileitem\.lostCityRumour")),
    ("nativeLand", re.compile(r"image\.tileitem\.nativeLand")),
    ("settlement", re.compile(r"image\.tileitem\.model\.settlement\.[A-Za-z.]+")),
    ("unit", re.compile(r"image\.unit\.model\.unit\.[A-Za-z.]+")),
    ("animation", re.compile(r"animation\.unit\.model\.unit\.[A-Za-z.]+")),
    ("building", re.compile(r"image\.buildingicon\.model\.building\.[A-Za-z.]+")),
    ("buildingBackground", re.compile(r"image\.buildingOutside\.background\.[A-Za-z.]+")),
    ("goods", re.compile(r"image\.icon\.model\.goods\.[A-Za-z]+")),
)

_NATION = "dutch|english|french|spanish|portuguese|danish|swedish|russian"
_SETTLEMENT_NATION = re.compile(rf"(resources/images/settlements/\w+)\.(?:{_NATION})\.png")
_BUILDING_NATION = re.compile(rf"(resources/images/buildings/[\w-]+?)-(?:{_NATION})\.png")


def classify(key: str) -> str | None:
    for family, pattern in FAMILIES:
        if pattern.fullmatch(key):
            return family
    return None


def canonical_path(path: str) -> str:
    """Nation-specific originals share one style in the mod."""
    for pattern in (_SETTLEMENT_NATION, _BUILDING_NATION):
        match = pattern.fullmatch(path)
        if match:
            return match.group(1) + ".png"
    return path


def hires_name(path: str, factor: int = 2) -> str:
    stem, dot, suffix = path.rpartition(".")
    return f"{stem}.size{factor}{dot}{suffix}"


def variation_name(path: str, index: int) -> str:
    """Name of variation ``index`` following FreeCol's sibling-file convention."""
    stem, dot, suffix = path.rpartition(".")
    prefix = re.sub(r"\d*$", "", stem)
    return f"{prefix}{index}{dot}{suffix}"


def sibling_variations(path: str, names: list[str]) -> list[str]:
    """Files FreeCol's FreeColDataFile would load as variations of ``path``."""
    directory, _, filename = path.rpartition("/")
    stem, _, suffix = filename.rpartition(".")
    prefix = re.sub(r"\d*$", "", stem)
    pattern = re.compile(re.escape(prefix) + r"\d\d?\." + re.escape(suffix))
    return sorted(
        name for name in names
        if name.rpartition("/")[0] == directory
        and name != path
        and pattern.fullmatch(name.rpartition("/")[2])
    )


@dataclass(frozen=True)
class ImageInfo:
    path: str
    width: int
    height: int
    bbox: tuple[int, int, int, int] | None
    hires: tuple[str, ...] = ()
    variations: tuple[str, ...] = ()


@dataclass
class Manifest:
    data_dir: Path
    entries: dict[str, str] = field(default_factory=dict)
    families: dict[str, str] = field(default_factory=dict)
    images: dict[str, ImageInfo] = field(default_factory=dict)

    def keys_for(self, path: str) -> list[str]:
        return [key for key, value in self.entries.items() if canonical_path(value) == path]

    def family_counts(self) -> dict[str, int]:
        counts: dict[str, int] = {}
        for family in self.families.values():
            counts[family] = counts.get(family, 0) + 1
        return counts


def alpha_bbox(image: Image.Image, threshold: int = 128) -> tuple[int, int, int, int] | None:
    alpha = np.asarray(image.convert("RGBA").getchannel("A"))
    rows = np.flatnonzero((alpha > threshold).any(axis=1))
    cols = np.flatnonzero((alpha > threshold).any(axis=0))
    if rows.size == 0:
        return None
    return int(cols[0]), int(rows[0]), int(cols[-1]) + 1, int(rows[-1]) + 1


def _inspect(data_dir: Path, path: str, with_variations: bool) -> ImageInfo:
    file = data_dir / path
    with Image.open(file) as image:
        width, height = image.size
        bbox = alpha_bbox(image)
    siblings = sorted(
        f"{path.rpartition('/')[0]}/{entry.name}" for entry in file.parent.iterdir() if entry.is_file()
    )
    stem, _, suffix = file.name.rpartition(".")
    hires_pattern = re.compile(re.escape(stem) + r"\.size\d+\." + re.escape(suffix))
    hires = tuple(name for name in siblings if hires_pattern.fullmatch(name.rpartition("/")[2]))
    variations = tuple(sibling_variations(path, siblings)) if with_variations else ()
    return ImageInfo(path, width, height, bbox, hires, variations)


def load_manifest(freecol_root: Path) -> Manifest:
    data_dir = freecol_root / "data" / "default"
    properties = read_properties(data_dir / "resources.properties")
    manifest = Manifest(data_dir=data_dir)
    for key, value in properties.items():
        family = classify(key)
        if family is None:
            continue
        manifest.entries[key] = value
        manifest.families[key] = family
    for key, value in manifest.entries.items():
        family = manifest.families[key]
        if value.startswith(RESOURCE_PREFIX) or family == "animation" or value in manifest.images:
            continue
        if not (data_dir / value).is_file():
            continue
        manifest.images[value] = _inspect(data_dir, value, with_variations=family != "river")
    return manifest
