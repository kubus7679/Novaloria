# Novaloria Atlas Graphics Mod

Novaloria Atlas replaces all 807 supported FreeCol graphics resource keys with
original Blender renders. The package includes 540 base and variation images,
their 2x versions, and 12 FreeCol attack-animation archives. It covers terrain,
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

For a map-art rebuild, use:

```sh
uv run --system-certs novaloria-art build --only terrain/ forest/ river/ misc/plowed
```

Partial builds retain the packaged resources that are not being regenerated.
Shorelines combine FreeCol's edge/corner bitmasks; river branches meet the
NE/SE/SW/NW edge midpoints at matching widths. Forests are fitted inside their
original canvas without moving the tile baseline. Hills use broad, low relief;
ground and plowed fields use layered earth tones. Roads are shaded directly
by Novaloria's shared map/colony renderer.

For an isolated comparison of selected sprites against the current Atlas, use
exact resource paths:

```sh
uv run --system-certs novaloria-art preview --paths \
  resources/images/units/civilian/expertFarmer.png \
  resources/images/goods/grain.png
```

The comparison sheet, individual 1x/2x images, raw renders, and Blender log
are written to `build/art/preview/` (or `--output`). The sheet includes native
size and enlarged views. This command does not update the mod, ZIP, staging
resources, or animations. A preview of one profession or good does not imply
the other types have already been redesigned. Scouts and other mounted roles
use a seated rider with legs on either side of the horse and hands connected to
the reins; the default free colonist wears a grey coat.

For the full unit and goods update, rebuild with `--only units/ goods/`. These
sprites include profession-specific equipment and distinct commodity forms.
All figures, including riders, use the same camera scale and logical canvas:
the person stays the same size regardless of equipment, while the seated pose
and horse retain their natural proportions. Figure renders use a higher sun
angle to keep their ground shadows within the shared frame.
The treasure train carries a locked chest, and damaged artillery has a broken
wheel. Ships have type-specific rigging and hull details, including mixed
square and lateen sails on galleons and distinct gun decks on frigates and
men-of-war. Mounted units use the same seated-rider
geometry across roles. Unit, ship and wagon rebuilds also regenerate the
corresponding attack animations; the man-of-war and Flying Dutchman have
their own animations instead of reusing another ship's sprite. Partial builds
use a fresh staging directory copied from the current package, so unselected
resources are not replaced by stale build output.

Portraits, monarchs, mercenaries, nation shields, UI art, map markers, and
unexplored-tile artwork are outside the replacement scope.