#!/usr/bin/env python3
"""Prepare a deterministic Native Trade fixture from a Java FreeCol autosave."""

import argparse
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


FIXTURE_USERNAME = "FreeColE2ENativeTrade"
SOURCE_UNIT_TYPE = "model.unit.freeColonist"
UNIT_TYPE = "model.unit.wagonTrain"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="Java-generated .fsg autosave")
    parser.add_argument("destination", type=Path, help="Fixture .fsg to create")
    args = parser.parse_args()

    xml_parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    with zipfile.ZipFile(args.source) as source:
        entries = {name: source.read(name) for name in source.namelist()}

    root = ET.fromstring(entries["savegame.xml"], parser=xml_parser)
    game = root.find("game")
    if game is None:
        raise SystemExit("Savegame has no game element")

    local_player = next(
        (
            player
            for player in game.findall("player")
            if player.get("playerType") == "colonial"
            and player.get("ai") == "false"
            and player.get("dead") != "true"
        ),
        None,
    )
    if local_player is None:
        raise SystemExit("Savegame has no living human colonial player")

    local_player_id = local_player.get("id")
    local_player.set("username", FIXTURE_USERNAME)
    game.set("currentPlayer", local_player_id)

    native_settlements = [
        settlement
        for settlement in game.iter("indianSettlement")
        if settlement.get("owner") in {
            player.get("id")
            for player in game.findall("player")
            if player.get("playerType") == "native" and player.get("dead") != "true"
        }
    ]
    for settlement in native_settlements:
        if not any(
            alarm.get("player") == local_player_id
            for alarm in settlement.findall("alarm")
        ):
            ET.SubElement(
                settlement, "alarm", {"player": local_player_id, "value": "0"}
            )
        goods_container = settlement.find("goodsContainer")
        if goods_container is not None:
            for goods in goods_container.iter("goods"):
                goods.set("amount", "500")
    tile_elements = game.find("map")
    if tile_elements is None:
        raise SystemExit("Savegame has no map")
    tiles = {
        tile.get("id"): tile for tile in tile_elements.findall("tile")
    }
    coordinates = {
        (int(tile.get("x", "-1")), int(tile.get("y", "-1"))): tile
        for tile in tiles.values()
    }

    target_tile = None
    for settlement in sorted(native_settlements, key=lambda item: item.get("id", "")):
        settlement_tile = tiles.get(settlement.get("tile"))
        if settlement_tile is None:
            continue
        x = int(settlement_tile.get("x", "-1"))
        y = int(settlement_tile.get("y", "-1"))
        odd_row = y % 2 == 1
        deltas = [
            (0, -2),
            (1 if odd_row else 0, -1),
            (1, 0),
            (1 if odd_row else 0, 1),
            (0, 2),
            (0 if odd_row else -1, 1),
            (-1, 0),
            (0 if odd_row else -1, -1),
        ]
        for dx, dy in deltas:
            candidate = coordinates.get((x + dx, y + dy))
            if candidate is None or "ocean" in candidate.get("type", "").lower():
                continue
            if any(child.tag in {"colony", "indianSettlement"} for child in candidate):
                continue
            target_tile = candidate
            break
        if target_tile is not None:
            break
    if target_tile is None:
        raise SystemExit("No land tile adjacent to a Native settlement")

    unit = next(
        (
            item
            for item in game.iter("unit")
            if item.get("owner") == local_player_id
            and item.get("unitType") == SOURCE_UNIT_TYPE
        ),
        None,
    )
    if unit is None:
        raise SystemExit(f"Savegame has no local {SOURCE_UNIT_TYPE} unit")

    parents = {child: parent for parent in game.iter() for child in parent}
    old_parent = parents.get(unit)
    if old_parent is None:
        raise SystemExit("Could not locate unit's current container")
    old_parent.remove(unit)

    target_tile.attrib.pop("owner", None)
    target_tile.attrib.pop("owningSettlement", None)
    unit.set("location", target_tile.get("id", ""))
    unit.set("unitType", UNIT_TYPE)
    unit.set("role", "model.role.default")
    unit.set("roleCount", "0")
    unit.set("movesLeft", "3")
    unit.set("state", "active")
    next_id = int(game.get("nextId", "0"))
    game.set("nextId", str(next_id + 1))
    ET.SubElement(
        unit, "goodsContainer", {"id": f"goodsContainer:{next_id}"}
    ).append(ET.Element("storedGoods"))
    target_tile.append(unit)

    entries["savegame.xml"] = ET.tostring(
        root, encoding="utf-8", xml_declaration=True
    )
    args.destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.destination, "w", zipfile.ZIP_DEFLATED) as destination:
        for name, data in entries.items():
            destination.writestr(name, data)

    print(
        f"Prepared {args.destination}: player={local_player_id}, "
        f"unit={unit.get('id')}, tile={target_tile.get('id')}"
    )


if __name__ == "__main__":
    main()
