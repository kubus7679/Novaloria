# Phase 48: Colony Build Queue & Buildings Panel

## Objective

Close the last open roadmap Phase 13 item — proper colony build-queue /
production / building UI — so the colony sheet lists the server-reported
buildings and drives the build queue from a spec-derived picker instead of raw
id text fields.

## Wire contract (verified against `freecol/`)

- Colony XML children (owner-visible): `<buildQueueItem id="model.building.*"/>`
  (ordered), `<populationQueueItem id="model.unit.*"/>`, `<building id=..
  buildingType="model.building.*"/>` (`common/model/Colony.java`).
- `setBuildQueue` uses freecol array attributes:
  `<setBuildQueue colony="c" x0=".." x1=".." xLength="2"/>`
  (`common/model/FreeColObject.arrayKey`, `Message.setArrayAttributes`) — the
  existing `GameState.setSelectedColonyBuildQueue` already matches this.
- Building definitions come from `<building-type id=.. upkeep=..
  required-population=.. upgrades-from=.. extends=..>` in the specification.

## Implementation Steps

1. `FreeColGame/Model/Specification.swift`: `BuildingTypeInfo` +
   `buildingTypes` parsed from `<building-type>` (with a `displayName` derived
   from the id).
2. `FreeColGame/Model/Colony.swift`: parse `buildQueueItem`,
   `populationQueueItem`, `building` children into ordered queues and a
   `buildings` list (`ColonyBuilding`).
3. `FreeColApp/GameState.swift`: `selectedColonyBuildableCandidates` (spec-known,
   not yet built, population requirement met), `selectedColonyBuildings`,
   `selectedColonyBuildQueue`, `buildingDisplayName(_:)`.
4. `FreeColApp/ColonyPanelView.swift`: Buildings list, build-queue picker +
   Add/Up/Down/Remove, Set/Reset buttons, and draft sync on server-driven
   `colony.buildQueue` changes.
5. `FreeColApp/GameView.swift`: pass the new model-derived inputs.
6. Tests: colony queue/building parsing + specification building types (CLI and
   XCTest).

## Validation

- `swift build --target FreeColApp`
- `swift test`
- `swift run FreeColProtocolCLI`

## Notes

- Buildable availability is an approximation (population gate + already-built
  filter); full Java parity would evaluate building abilities/required goods.
- Production totals/turns are not computed client-side; the panel shows the
  queue and buildings reported by the server.
