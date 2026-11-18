"""Render specifications: which Blender kit replaces which FreeCol image."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import PurePosixPath
from typing import Any

from .manifest import RESOURCE_PREFIX, Manifest, canonical_path

IMAGES = "resources/images/"
TILE = (128, 64)
FOREST = (128, 84)
OVERLAY = (128, 96)


@dataclass(frozen=True)
class Spec:
    kit: str
    params: dict[str, Any] = field(default_factory=dict)
    mode: str = "sprite"
    align: str = "baseline"
    canvas: tuple[int, int] | None = None
    elevation: float = 30.0


def _tile(kind: str) -> Spec:
    return Spec("terrain", {"type": kind}, mode="tile", canvas=TILE)


def _forest(kind: str) -> Spec:
    return Spec("forest", {"type": kind}, mode="overlay", canvas=FOREST)


def _relief(kind: str) -> Spec:
    return Spec("relief", {"type": kind}, mode="overlay", canvas=OVERLAY)


def _figure(profession: str, **params: Any) -> Spec:
    return Spec("figure", {"profession": profession, **params}, elevation=18.0)


def _building(kind: str) -> Spec:
    return Spec("building", {"type": kind}, align="fit", elevation=28.0)


def _goods(kind: str) -> Spec:
    return Spec("goods", {"type": kind}, align="icon", elevation=35.0)


SPECS: dict[str, Spec] = {
    IMAGES + "terrain/plains/center0.png": _tile("plains"),
    IMAGES + "terrain/grassland/center0.png": _tile("grassland"),
    IMAGES + "terrain/prairie/center0.png": _tile("prairie"),
    IMAGES + "terrain/desert/center0.png": _tile("desert"),
    IMAGES + "terrain/tundra/center0.png": _tile("tundra"),
    IMAGES + "terrain/marsh/center0.png": _tile("marsh"),
    IMAGES + "terrain/arctic/center0.png": _tile("arctic"),
    IMAGES + "terrain/ocean/center0.png": _tile("ocean"),
    IMAGES + "forest/mixed/mixed.png": _forest("mixed"),
    IMAGES + "forest/conifer/conifer.png": _forest("conifer"),
    IMAGES + "terrain/hills/hills0.png": _relief("hills"),
    IMAGES + "terrain/mountains/mountains0.png": _relief("mountains"),
    IMAGES + "units/civilian/freeColonist.png": _figure("colonist"),
    IMAGES + "units/soldier/soldier.png": _figure("soldier"),
    IMAGES + "units/dragoon/dragoon.png": _figure("dragoon", mounted=True),
    IMAGES + "units/ship/caravel.png": Spec("ship", {"type": "caravel"}, align="fit", elevation=22.0),
    IMAGES + "units/wagon/wagonTrain.png": Spec("wagon", {"type": "wagonTrain"}, align="fit", elevation=24.0),
    IMAGES + "buildings/townhall.png": _building("townHall"),
    IMAGES + "buildings/carpenters_house.png": _building("carpenterHouse"),
    IMAGES + "buildings/church.png": _building("church"),
    IMAGES + "settlements/small.png": Spec("settlement", {"size": "small"}, align="fit"),
    IMAGES + "settlements/medium.png": Spec("settlement", {"size": "medium"}, align="fit"),
    IMAGES + "goods/food.png": _goods("food"),
    IMAGES + "goods/furs.png": _goods("furs"),
    IMAGES + "goods/rum.png": _goods("rum"),
    IMAGES + "goods/tools.png": _goods("tools"),
    IMAGES + "goods/muskets.png": _goods("muskets"),
    IMAGES + "bonus/grain.png": Spec("bonus", {"type": "grain"}, align="fit", elevation=32.0),
    IMAGES + "misc/lostCityRumour.png": Spec("lcr", {}, align="fit"),
}

PROTOTYPE: frozenset[str] = frozenset(SPECS)


def _generated_spec(path: str, family: str, key: str) -> Spec | None:
    image = PurePosixPath(path)
    name = image.stem
    parent = image.parent.name
    if family == "tile":
        return _tile(parent)
    if family == "forest":
        return _forest(parent)
    if family == "overlay":
        return _relief(parent)
    if family == "beach":
        mode = "tile" if name == "center0" else "overlay"
        return Spec("beach", {"type": name}, mode=mode, canvas=TILE)
    if family == "delta":
        return Spec("delta", {"type": name}, mode="overlay", canvas=TILE)
    if family == "river":
        style = key.rsplit(".s", 1)[-1]
        return Spec("river", {"style": style}, mode="overlay", canvas=TILE)
    if family == "riverTexture":
        return Spec("riverTexture", {"type": name}, mode="tile", canvas=TILE)
    if family == "plow":
        return Spec("plow", {}, mode="overlay", canvas=TILE)
    if family == "clouds":
        return Spec("clouds", {}, mode="overlay", canvas=(128, 96))
    if family == "bonus":
        resource = key.rsplit(".", 1)[-1]
        return Spec("bonus", {"type": resource}, align="fit", elevation=32.0)
    if family == "lcr":
        return Spec("lcr", {}, align="fit")
    if family == "nativeLand":
        return Spec("nativeLand", {}, align="icon")
    if family == "settlement":
        return Spec("settlement", {"type": name}, align="fit")
    if family == "unit":
        unit = key.removeprefix("image.unit.model.unit.").split(".", 1)[0]
        if parent == "ship":
            return Spec("ship", {"type": name}, align="fit", elevation=22.0)
        if parent == "wagon":
            return Spec("wagon", {"type": name}, align="fit", elevation=24.0)
        return _figure(
            name,
            unit=unit,
            role=parent,
            mounted=parent in {"dragoon", "cavalry", "mountedBrave", "nativeDragoon"},
        )
    if family == "building":
        building = key.removeprefix("image.buildingicon.model.building.").split(".", 1)[0]
        return _building(building)
    if family == "buildingBackground":
        return Spec("buildingBackground", {"type": name}, align="fit", elevation=18.0)
    if family == "goods":
        good = key.rsplit(".", 1)[-1]
        return _goods(good)
    return None


def full_specs(manifest: Manifest) -> dict[str, Spec]:
    """Return one render spec per concrete image path referenced by supported families."""
    path_info: dict[str, tuple[str, str]] = {}
    for key, value in manifest.entries.items():
        if value.startswith(RESOURCE_PREFIX):
            continue
        path = canonical_path(value)
        if path not in manifest.images:
            path = value
        if path in manifest.images:
            path_info.setdefault(path, (manifest.families[key], key))

    result = dict(SPECS)
    for path, (family, key) in path_info.items():
        if path not in result:
            spec = _generated_spec(path, family, key)
            if spec is not None:
                result[path] = spec
    return result
