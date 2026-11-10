#!/usr/bin/env python3
"""Import FreeCol terrain, localized names and illustrated Colopedia content."""
import argparse
import json
from pathlib import Path
import re
import shutil
import xml.etree.ElementTree as ET

MODEL_MESSAGE_KEYS = {
    "model.disaster.strikes",
    "model.game.spanishSuccession",
    "model.message.independence",
    "model.monarch.action.raiseTaxAct.text",
    "model.monarch.action.raiseTaxWar.text",
    "model.player.dead.european",
    "model.player.disaster.bankruptcy.start",
    "model.player.disaster.bankruptcy.stop",
    "model.player.ignoredMercenaries",
    "model.player.interventionForceArrives",
    "tradeRoute.prefix",
}


def properties(path):
    return dict(line.split("=", 1) for line in path.read_text().splitlines()
                if line and not line.startswith(("#", "!")) and "=" in line)


def plain_text(value, variant="default"):
    if value.startswith(("{{plural:", "{{tag:")):
        options = dict(part.split("=", 1) for part in value[2:-2].split("|")[1:] if "=" in part)
        value = options.get(variant, options.get("default", options.get("one", "")))
    return value if "{{" not in value and "%" not in value else ""


def model_message_text(value):
    value = re.sub(r"\{\{tag:country\|([^{}]*)\}\}", r"\1", value)
    return value if "{{" not in value else ""


def import_colopedia(source, target, resources, resolve, messages, fallback_messages, locale):
    root = ET.parse(source / "data/rules/classic/specification.xml").getroot()
    categories = {"unit-type": "units", "goods-type": "goods", "tile-type": "terrain",
                  "building-type": "buildings", "tile-improvement-type": "improvements",
                  "founding-father": "fathers", "nation": "nations", "resource-type": "resources",
                  "role": "roles"}
    definitions = {node.get("id"): node for node in root.iter() if node.tag in categories and node.get("id")}
    icons = target / "colopedia"
    icons.mkdir(exist_ok=True)

    def message(key):
        return messages.get(key) or fallback_messages.get(key, "")

    def title(identifier):
        return plain_text(message(identifier + ".name"), "country") or re.sub(
            r"([a-z])([A-Z])", r"\1 \2", identifier.rsplit(".", 1)[-1]).capitalize()

    def inherited(node, visited=()):
        parent = node.get("extends")
        if parent in definitions and parent not in visited:
            attrs = inherited(definitions[parent], visited + (parent,))
        else:
            attrs = {}
        return attrs | node.attrib

    entries = []
    labels = {
        "de": {"line-of-sight": "Sichtweite", "offence": "Angriff", "defence": "Verteidigung",
               "space": "Frachtplätze", "skill": "Fähigkeitsstufe", "price": "Preis in Gold",
               "workplaces": "Arbeitsplätze", "required-population": "Benötigte Bevölkerung",
               "upkeep": "Unterhalt in Gold", "add-work-turns": "Zusätzliche Arbeitsrunden",
               "maximum-count": "Maximale Ausrüstung"},
        "en": {"line-of-sight": "Line of sight", "offence": "Offence", "defence": "Defence",
               "space": "Cargo space", "skill": "Skill level", "price": "Price in gold",
               "workplaces": "Workplaces", "required-population": "Required population",
               "upkeep": "Upkeep in gold", "add-work-turns": "Additional work turns",
               "maximum-count": "Maximum equipment"},
        "es": {"line-of-sight": "Alcance visual", "offence": "Ataque", "defence": "Defensa",
               "space": "Espacio de carga", "skill": "Nivel de habilidad", "price": "Precio en oro",
               "workplaces": "Puestos de trabajo", "required-population": "Población requerida",
               "upkeep": "Mantenimiento en oro", "add-work-turns": "Turnos de trabajo adicionales",
               "maximum-count": "Equipamiento máximo"},
    }[locale]
    movement_labels = {"de": "Bewegungspunkte", "en": "Movement Points", "es": "Puntos de movimiento"}
    for identifier, node in definitions.items():
        if not identifier.startswith("model.") or node.get("abstract") == "true":
            continue
        attrs = inherited(node)
        facts = [{"label": label, "value": attrs[key]} for key, label in labels.items() if key in attrs]
        if "movement" in attrs:
            facts.append({"label": movement_labels[locale], "value": f'{int(attrs["movement"]) / 3:g}'})
        related = set()
        for key in ("upgrades-from", "expert-production", "expert-unit", "made-from", "required-role"):
            if attrs.get(key, "").startswith("model."):
                related.add(attrs[key])
        for child in node.iter():
            if child.tag in ("required-goods", "output", "input"):
                goods = child.get("goods-type", child.get("id"))
                if goods:
                    related.add(goods)
                    label = {
                        "de": {"required-goods": "Baukosten / Ausrüstung", "output": "Produktion",
                               "input": "Verbrauch"},
                        "en": {"required-goods": "Build cost / equipment", "output": "Production",
                               "input": "Consumption"},
                        "es": {"required-goods": "Coste de construcción / equipamiento", "output": "Producción",
                               "input": "Consumo"},
                    }[locale][child.tag]
                    facts.append({"label": f"{label}: {title(goods)}", "value": child.get("value", "")})
        translated_labels = {
            "de": {"ruler": "Herrscher", "newLandName": "Name der Neuen Welt", "birthAndDeath": "Lebensdaten"},
            "en": {"ruler": "Ruler", "newLandName": "Name of the New World", "birthAndDeath": "Lifespan"},
            "es": {"ruler": "Gobernante", "newLandName": "Nombre del Nuevo Mundo", "birthAndDeath": "Vida y muerte"},
        }[locale]
        for key, label in translated_labels.items():
            value = plain_text(message(identifier + "." + key))
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
                        "summary": plain_text(message(identifier + ".description")),
                        "text": plain_text(message(identifier + ".text")),
                        "facts": facts, "related": sorted(related), "icon": icon})
    destination = target / f"{locale}.lproj" if locale != "de" else target
    destination.mkdir(exist_ok=True)
    (destination / f"colopedia-{locale}.json").write_text(
        json.dumps(entries, ensure_ascii=False, indent=2) + "\n"
    )
    print(f"Imported {len(entries)} Colopedia entries.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="path to the FreeCol source tree")
    parser.add_argument("--locale", choices=("de", "en", "es"), default="de")
    args = parser.parse_args()
    source = Path(args.source).resolve()
    locale = args.locale
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
    locale_file = {
        "de": "FreeColMessages_de.properties",
        "en": "FreeColMessages_en_GB.properties",
        "es": "FreeColMessages_es_ES.properties",
    }[locale]
    fallback_messages = properties(source / "data/strings/FreeColMessages.properties")
    messages = fallback_messages.copy()
    messages.update(properties(source / "data/strings" / locale_file))
    if locale == "de":
        fallback_messages = {}
    names = {}
    name_messages = messages
    if locale == "es":
        name_messages = fallback_messages | messages
    for key, value in name_messages.items():
        if not key.startswith("model.") or not key.endswith(".name"):
            continue
        value = plain_text(value)
        if value:
            names[key[:-5]] = value
    destination = target / f"{locale}.lproj" if locale != "de" else target
    destination.mkdir(exist_ok=True)
    (destination / f"object-names-{locale}.json").write_text(
        json.dumps(names, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    if locale != "de":
        model_messages = {}
        for key, value in messages.items():
            if (
                key in MODEL_MESSAGE_KEYS
                or key.startswith("model.") and re.search(r"%[A-Za-z][A-Za-z0-9_]*%", value)
            ):
                text = model_message_text(value)
                if text:
                    model_messages[key] = text
        # These two legacy IDs are absent from FreeCol's properties files.
        # The client still emits them, so provide concise localized fallbacks.
        # The tax-act text is simplified because its nested tag alternatives
        # are not supported by the client's %name% template formatter.
        model_messages.update({
            "model.disaster.strikes": {
                "en": "The disaster %disaster% strikes your colony %colony%.",
                "es": "El desastre %disaster% golpea tu colonia %colony%.",
            }[locale],
            "model.message.independence": {
                "en": "Independence has been declared.",
                "es": "Se ha declarado la independencia.",
            }[locale],
            "model.monarch.action.raiseTaxAct.text": {
                "en": "Acts of defiance by the disloyal colonists in %newWorld% leave Us no choice but to raise the tax to %amount%%. If you do not agree, We will boycott your %goods%!",
                "es": "Los actos de desafío de los colonos desleales de %newWorld% no nos dejan otra opción que elevar el impuesto al %amount%%. Si no aceptáis, boicotearemos vuestras %goods%.",
            }[locale],
        })
        (destination / f"model-message-texts-{locale}.json").write_text(
            json.dumps(model_messages, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    shutil.copyfile(source / "LICENSE", target / "FreeCol-COPYING")
    import_colopedia(source, target, resources, resolve, messages, fallback_messages, locale)
    print(f"Imported terrain layers and {len(names)} {locale} object names.")


if __name__ == "__main__":
    main()
