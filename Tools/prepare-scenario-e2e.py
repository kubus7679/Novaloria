#!/usr/bin/env python3
"""Prepare deterministic diplomacy, combat, and missionary fixtures."""

import argparse
import copy
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


FIXTURE_USERNAME = "FreeColE2ENativeTrade"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="Validated Native Trade .fsg fixture")
    parser.add_argument("destination", type=Path, help="Scenario .fsg fixture to create")
    args = parser.parse_args()

    xml_parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    with zipfile.ZipFile(args.source) as source:
        entries = {name: source.read(name) for name in source.namelist()}

    root = ET.fromstring(entries["savegame.xml"], parser=xml_parser)
    game = root.find("game")
    if game is None:
        raise SystemExit("Savegame has no game element")

    players = {player.get("id"): player for player in game.findall("player")}
    local_player = next(
        (player for player in players.values()
         if player.get("username") == FIXTURE_USERNAME),
        None,
    )
    if local_player is None:
        raise SystemExit(f"Savegame has no player named {FIXTURE_USERNAME}")

    map_element = game.find("map")
    if map_element is None:
        raise SystemExit("Savegame has no map")
    tiles = {
        tile.get("id"): tile for tile in map_element.findall("tile")
    }
    coordinates = {
        (int(tile.get("x", "-1")), int(tile.get("y", "-1"))): tile
        for tile in tiles.values()
    }

    def neighbors(tile: ET.Element) -> list[ET.Element]:
        x = int(tile.get("x", "-1"))
        y = int(tile.get("y", "-1"))
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
        return [
            neighbor
            for dx, dy in deltas
            if (neighbor := coordinates.get((x + dx, y + dy))) is not None
        ]

    def is_land(tile: ET.Element) -> bool:
        tile_type = tile.get("type", "").lower()
        return "ocean" not in tile_type and "highseas" not in tile_type

    local_player_id = local_player.get("id")
    wagon = next(
        (
            unit for unit in game.iter("unit")
            if unit.get("owner") == local_player_id
            and unit.get("unitType") == "model.unit.wagonTrain"
            and unit.get("location") in tiles
        ),
        None,
    )
    if wagon is None:
        raise SystemExit("Savegame has no local wagon on the map")
    wagon_tile = tiles[wagon.get("location")]

    native_settlement = next(
        (
            settlement for settlement in game.iter("indianSettlement")
            if (owner := players.get(settlement.get("owner"))) is not None
            and owner.get("playerType", "").lower() in {"native", "indian"}
            and settlement.get("tile") in tiles
            and tiles[settlement.get("tile")] in neighbors(wagon_tile)
        ),
        None,
    )
    if native_settlement is None:
        raise SystemExit("No adjacent Native settlement for the local wagon")
    native_player_id = native_settlement.get("owner")
    native_tile = tiles[native_settlement.get("tile")]

    next_id = int(game.get("nextId", "0"))

    def allocate_id(prefix: str) -> str:
        nonlocal next_id
        result = f"{prefix}:{next_id}"
        next_id += 1
        return result

    ai_candidates = sorted(
        (
            player for player in players.values()
            if player.get("playerType", "").lower() in {"colonial", "european"}
            and player.get("ai") == "true"
            and player.get("dead") != "true"
        ),
        key=lambda player: player.get("id", ""),
    )
    ai_player = next(
        (
            player for player in ai_candidates
            if any(
                unit.get("owner") == player.get("id")
                and unit.get("location") in tiles
                and "ocean" not in tiles[unit.get("location")].get("type", "").lower()
                for unit in game.iter("unit")
            )
        ),
        None,
    )
    if ai_player is None:
        raise SystemExit("Savegame has no European AI land unit")
    ai_player_id = ai_player.get("id")

    colony_tile = next(
        (
            tile for tile in neighbors(wagon_tile)
            if is_land(tile)
            and tile is not native_tile
            and native_tile in neighbors(tile)
            and not any(
                child.tag in {"colony", "indianSettlement", "unit", "tileItemContainer"}
                for child in tile
            )
        ),
        None,
    )
    if colony_tile is None:
        raise SystemExit("No empty land tile adjacent to both units and a settlement")

    colony_id = allocate_id("colony")
    colony_tile.attrib.pop("owningSettlement", None)
    colony_tile.set("owner", ai_player_id)
    colony_tile.set("owningSettlement", colony_id)
    colony_tile.append(ET.Element("colony", {
        "id": colony_id,
        "owner": ai_player_id,
        "tile": colony_tile.get("id", ""),
        "settlementType": "model.settlement.colony",
        "name": "E2E Colony",
        "established": "2",
        "sonsOfLiberty": "0",
        "oldSonsOfLiberty": "0",
        "tories": "0",
        "oldTories": "0",
        "liberty": "0",
        "immigration": "0",
        "productionBonus": "0",
        "unitCount": "1",
    }))

    parents = {child: parent for parent in game.iter() for child in parent}

    def add_unit(unit_type: str, role: str, role_count: str) -> ET.Element:
        nonlocal next_id
        unit = copy.deepcopy(wagon)
        unit.set("id", allocate_id("unit"))
        unit.set("unitType", unit_type)
        unit.set("role", role)
        unit.set("roleCount", role_count)
        unit.set("owner", local_player_id)
        unit.set("location", wagon_tile.get("id", ""))
        unit.set("movesLeft", "3")
        unit.set("state", "active")

        goods_container = unit.find("goodsContainer")
        if goods_container is not None:
            goods_container.set("id", allocate_id("goodsContainer"))
            for child in list(goods_container):
                goods_container.remove(child)

        wagon_tile.append(unit)
        return unit

    add_unit("model.unit.seasonedScout", "model.role.scout", "1")
    add_unit("model.unit.jesuitMissionary", "model.role.missionary", "1")

    defender = next(
        (
            unit for unit in game.iter("unit")
            if unit.get("owner") == ai_player_id
            and unit.get("unitType") == "model.unit.veteranSoldier"
            and unit.get("location") in tiles
        ),
        None,
    )
    attacker = next(
        (
            unit for unit in game.iter("unit")
            if unit.get("owner") == local_player_id
            and unit.get("unitType") == "model.unit.veteranSoldier"
        ),
        None,
    )
    if defender is None or attacker is None:
        raise SystemExit("Savegame lacks a local and AI veteran soldier")
    defender_tile = tiles[defender.get("location")]
    attack_tile = next(
        (
            tile for tile in neighbors(defender_tile)
            if is_land(tile)
            and tile is not colony_tile
            and not any(child.tag in {"colony", "indianSettlement", "unit"} for child in tile)
        ),
        None,
    )
    if attack_tile is None:
        raise SystemExit("No empty land tile adjacent to the AI veteran soldier")

    attacker_parent = parents.get(attacker)
    if attacker_parent is None:
        raise SystemExit("Could not locate the local veteran soldier")
    attacker_parent.remove(attacker)
    attacker.set("location", attack_tile.get("id", ""))
    attacker.set("movesLeft", "3")
    attacker.set("state", "active")
    attack_tile.append(attacker)

    def set_stance(player_id: str, other_player_id: str, value: str) -> None:
        player = players[player_id]
        for stance in list(player.findall("stance")):
            if stance.get("player") == other_player_id:
                player.remove(stance)
        ET.SubElement(player, "stance", {"player": other_player_id, "value": value})

    set_stance(local_player_id, ai_player_id, "war")
    set_stance(ai_player_id, local_player_id, "war")
    set_stance(local_player_id, native_player_id, "peace")
    set_stance(native_player_id, local_player_id, "peace")
    game.set("currentPlayer", local_player_id)
    game.set("nextId", str(next_id))

    entries["savegame.xml"] = ET.tostring(
        root, encoding="utf-8", xml_declaration=True
    )
    args.destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.destination, "w", zipfile.ZIP_DEFLATED) as destination:
        for name, data in entries.items():
            destination.writestr(name, data)

    print(
        f"Prepared {args.destination}: player={local_player_id}, "
        f"native={native_settlement.get('id')}, colony={colony_id}, "
        f"combat={attacker.get('id')} vs {defender.get('id')}"
    )


if __name__ == "__main__":
    main()
