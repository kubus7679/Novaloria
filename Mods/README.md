# Novaloria Atlas Graphics Mod

Novaloria Atlas replaces all 807 supported FreeCol graphics resource keys with
original Blender renders. The package includes 540 base and variation images,
their 2x versions, and 10 FreeCol attack-animation archives. It covers terrain,
shorelines, rivers, forests, resources, units, settlements, buildings, goods,
and backgrounds. The visual direction is inspired by the warm, dimensional
rendering of We the People; no WtP or Civ4 art files are included. The package
includes FreeCol's GPL license and credits.

## Install in FreeCol

Copy the `NovaloriaAtlas` folder or `NovaloriaAtlas.zip` into either
`<FreeCol>/data/mods` or `~/Library/Application Support/freecol/mods`. Enable
**Novaloria Atlas** in FreeCol's client options under Mods.

## Use in Novaloria

Open Mods in Novaloria, choose the FreeCol installation directory containing
`FreeCol.jar` and `data/`, then enable **Novaloria Atlas**. Install the mod in
that installation's `data/mods/` folder or in
`~/Library/Application Support/freecol/mods/`. The map, unit,
settlement, goods, terrain improvement, and Colopedia image lookups use the
active mod. Novaloria keeps the original logical image size while loading the
largest available `.sizeN` sibling.

## Build

The build requires Blender and uv. From the repository root:

```sh
cd Tools/art
uv sync --system-certs
uv run --system-certs novaloria-art build
```

Use `uv run --system-certs novaloria-art build --prototype` for the smaller style sample.
Review images are written to `build/art/review/`. The package is written to
`Mods/NovaloriaAtlas/` and `Mods/NovaloriaAtlas.zip`. The full build reports
coverage by FreeCol resource family and retains existing `mod.xml` and
`FreeColMessages.properties` metadata.

Portraits, monarchs, mercenaries, nation shields, UI art, map markers, and
unexplored-tile artwork are outside the replacement scope.