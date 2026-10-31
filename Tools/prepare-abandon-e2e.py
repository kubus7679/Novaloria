#!/usr/bin/env python3
"""Add an empty local colony to a Java-validated scenario fixture."""

import argparse
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


FIXTURE_USERNAME = "FreeColE2ENativeTrade"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="Validated scenario .fsg fixture")
    parser.add_argument("destination", type=Path, help="Abandonment .fsg fixture to create")
    args = parser.parse_args()

    xml_parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    with zipfile.ZipFile(args.source) as source:
        entries = {name: source.read(name) for name in source.namelist()}

    root = ET.fromstring(entries["savegame.xml"], parser=xml_parser)
    game = root.find("game")
    if game is None:
        raise SystemExit("Savegame has no game element")

    local_player = next(
        (player for player in game.findall("player")
         if player.get("username") == FIXTURE_USERNAME),
        None,
    )
    if local_player is None or local_player.get("id") is None:
        raise SystemExit(f"Savegame has no player named {FIXTURE_USERNAME}")

    map_element = game.find("map")
    if map_element is None:
        raise SystemExit("Savegame has no map element")
    tiles = {
        tile.get("id"): tile for tile in map_element.findall("tile")
        if tile.get("id") is not None
    }

    wagon = next(
        (
            unit for unit in game.iter("unit")
            if unit.get("owner") == local_player.get("id")
            and unit.get("unitType") == "model.unit.wagonTrain"
            and unit.get("location") in tiles
        ),
        None,
    )
    if wagon is None:
        raise SystemExit("Savegame has no local wagon on the map")
    wagon_tile = tiles[wagon.get("location")]
    wagon_x = int(wagon_tile.get("x", "0"))
    wagon_y = int(wagon_tile.get("y", "0"))

    candidates = [
        tile for tile in tiles.values()
        if "ocean" not in tile.get("type", "").lower()
        and "highseas" not in tile.get("type", "").lower()
        and tile.get("owner") is None
        and tile.get("owningSettlement") is None
        and not any(child.tag in {"colony", "indianSettlement", "unit", "tileItemContainer"}
                    for child in tile)
    ]
    if not candidates:
        raise SystemExit("Savegame has no empty land tile for the test colony")
    tile = min(
        candidates,
        key=lambda candidate: (
            abs(int(candidate.get("x", "0")) - wagon_x)
            + abs(int(candidate.get("y", "0")) - wagon_y),
            candidate.get("id", ""),
        ),
    )

    colony_id = f"colony:{int(game.get('nextId', '0'))}"
    game.set("nextId", str(int(game.get("nextId", "0")) + 1))
    tile.set("owner", local_player.get("id", ""))
    tile.set("owningSettlement", colony_id)
    tile.append(ET.Element("colony", {
        "id": colony_id,
        "owner": local_player.get("id", ""),
        "tile": tile.get("id", ""),
        "settlementType": "model.settlement.colony",
        "name": "E2E Abandonment",
        "established": "1",
        "sonsOfLiberty": "0",
        "oldSonsOfLiberty": "0",
        "tories": "0",
        "oldTories": "0",
        "liberty": "0",
        "immigration": "0",
        "productionBonus": "0",
        "unitCount": "0",
    }))

    entries["savegame.xml"] = ET.tostring(
        root, encoding="utf-8", xml_declaration=True
    )
    args.destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.destination, "w", zipfile.ZIP_DEFLATED) as destination:
        for name, data in entries.items():
            destination.writestr(name, data)

    print(f"Prepared {args.destination}: colony={colony_id}, tile={tile.get('id')}")


if __name__ == "__main__":
    main()
