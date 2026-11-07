#!/usr/bin/env python3
"""Import FreeCol terrain, German names and illustrated Colopedia content."""
import json
from pathlib import Path
import re
import shutil
import sys
import xml.etree.ElementTree as ET


def properties(path):
    return dict(line.split("=", 1) for line in path.read_text().splitlines()
                if line and not line.startswith(("#", "!")) and "=" in line)


def plain_text(value, variant="default"):
    if value.startswith(("{{plural:", "{{tag:")):
        options = dict(part.split("=", 1) for part in value[2:-2].split("|")[1:] if "=" in part)
        value = options.get(variant, options.get("default", options.get("one", "")))
    return value if "{{" not in value and "%" not in value else ""


def import_colopedia(source, target, resources, resolve, messages):
    root = ET.parse(source / "data/rules/classic/specification.xml").getroot()
    categories = {"unit-type": "units", "goods-type": "goods", "tile-type": "terrain",
                  "building-type": "buildings", "tile-improvement-type": "improvements",
                  "founding-father": "fathers", "nation": "nations", "resource-type": "resources",
                  "role": "roles"}
    definitions = {node.get("id"): node for node in root.iter() if node.tag in categories and node.get("id")}
    icons = target / "colopedia"
    icons.mkdir(exist_ok=True)

    def title(identifier):
        return plain_text(messages.get(identifier + ".name", ""), "country") or re.sub(
            r"([a-z])([A-Z])", r"\1 \2", identifier.rsplit(".", 1)[-1]).capitalize()

    def inherited(node, visited=()):
        parent = node.get("extends")
        if parent in definitions and parent not in visited:
            attrs = inherited(definitions[parent], visited + (parent,))
        else:
            attrs = {}
        return attrs | node.attrib

    entries = []
    labels = {"line-of-sight": "Sichtweite", "offence": "Angriff", "defence": "Verteidigung",
              "space": "Frachtplätze", "skill": "Fähigkeitsstufe", "price": "Preis in Gold",
              "workplaces": "Arbeitsplätze", "required-population": "Benötigte Bevölkerung",
              "upkeep": "Unterhalt in Gold", "add-work-turns": "Zusätzliche Arbeitsrunden",
              "maximum-count": "Maximale Ausrüstung"}
    for identifier, node in definitions.items():
        if not identifier.startswith("model.") or node.get("abstract") == "true":
            continue
        attrs = inherited(node)
        facts = [{"label": label, "value": attrs[key]} for key, label in labels.items() if key in attrs]
        if "movement" in attrs:
            facts.append({"label": "Bewegungspunkte", "value": f'{int(attrs["movement"]) / 3:g}'})
        related = set()
        for key in ("upgrades-from", "expert-production", "expert-unit", "made-from", "required-role"):
            if attrs.get(key, "").startswith("model."):
                related.add(attrs[key])
        for child in node.iter():
            if child.tag in ("required-goods", "output", "input"):
                goods = child.get("goods-type", child.get("id"))
                if goods:
                    related.add(goods)
                    label = {"required-goods": "Baukosten / Ausrüstung", "output": "Produktion",
                             "input": "Verbrauch"}[child.tag]
                    facts.append({"label": f"{label}: {title(goods)}", "value": child.get("value", "")})
        for key, label in (("ruler", "Herrscher"), ("newLandName", "Name der Neuen Welt"),
                           ("birthAndDeath", "Lebensdaten")):
            value = plain_text(messages.get(identifier + "." + key, ""))
            if value:
                facts.append({"label": label, "value": value})
        image_keys = {
            "units": f"image.unit.{identifier}",
            "goods": f"image.icon.{identifier}", "buildings": f"image.buildingicon.{identifier}",
            "fathers": f"image.flavor.{identifier}", "nations": f"image.miscicon.{identifier}",
            "resources": f"image.tileitem.{identifier}",
            "improvements": f"image.tile.{identifier}",
            "roles": f'image.unit.model.unit.freeColonist.{identifier.rsplit(".", 1)[-1]}',
        }
        category = categories[node.tag]
        image_key = image_keys.get(category)
        if category == "units" and (target / "units" / (identifier.rsplit(".", 1)[-1] + ".png")).exists():
            image_key = None
        icon = None
        if image_key in resources:
            image = source / "data/default" / resolve(image_key)
            icon = identifier + image.suffix
            shutil.copyfile(image, icons / icon)
        entries.append({"id": identifier, "category": category, "title": title(identifier),
                        "summary": plain_text(messages.get(identifier + ".description", "")),
                        "text": plain_text(messages.get(identifier + ".text", "")),
                        "facts": facts, "related": sorted(related), "icon": icon})
    (target / "colopedia-de.json").write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n")
    print(f"Imported {len(entries)} Colopedia entries.")


def main():
    source = Path(sys.argv[1]).resolve()
    target = Path(__file__).resolve().parents[1] / "Sources/Novaloria/Resources"
    resources = properties(source / "data/default/resources.properties")

    def resolve(key):
        value = resources[key]
        return resolve(value[9:]) if value.startswith("resource:") else value

    for key in resources:
        match = re.fullmatch(r"image\.tile\.model\.tile\.(\w+)\.center", key)
        overlay = re.fullmatch(r"image\.tile(?:forest|overlay)\.model\.tile\.(\w+)", key)
        beach = re.fullmatch(r"image\.tile\.model\.tile\.beach\.(edge|corner)(\d+)", key)
        resource = re.fullmatch(r"image\.tileitem\.model\.resource\.(\w+)", key)
        if match:
            name = f"{match[1]}_base"
        elif overlay:
            name = f"{overlay[1]}_overlay"
        elif beach:
            name = f"beach_{beach[1]}{beach[2]}"
        elif resource:
            name = f"resource_{resource[1]}"
        else:
            continue
        shutil.copyfile(source / "data/default" / resolve(key), target / "terrain" / f"{name}.png")

    shutil.copyfile(source / "data/default" / resolve("image.tileitem.lostCityRumour"),
                    target / "terrain" / "lostCityRumour.png")
    messages = properties(source / "data/strings/FreeColMessages.properties")
    messages.update(properties(source / "data/strings/FreeColMessages_de.properties"))
    names = {}
    for key, value in messages.items():
        if not key.startswith("model.") or not key.endswith(".name"):
            continue
        value = plain_text(value)
        if value:
            names[key[:-5]] = value
    (target / "object-names-de.json").write_text(
        json.dumps(names, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    shutil.copyfile(source / "LICENSE", target / "FreeCol-COPYING")
    import_colopedia(source, target, resources, resolve, messages)
    print(f"Imported terrain layers and {len(names)} German object names.")


if __name__ == "__main__":
    main()
