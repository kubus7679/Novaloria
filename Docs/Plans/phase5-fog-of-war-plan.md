# Phase 5 Implementation Plan - Fog of War / Visibility / Map Overlays

## Objective

Add a lightweight client-side fog overlay so the map better reflects what the local player can currently see.

## Scope

- Classify tiles as visible or fogged using a small local heuristic.
- Dim fogged tiles and suppress hidden terrain/unit detail in the map renderer.
- Keep the change local to the Swift client; do not alter protocol behavior.

## Execution Steps

1. [x] Add a shared visibility helper in `FreeColGame` for local-map heuristics.
2. [x] Render fogged tiles as dark overlays in `MapView`.
3. [x] Hide units and settlements on fogged tiles.
4. [x] Add a regression for the visibility helper in the CLI suite.
5. [x] Validate with build + tests.

## Validation

- `swift build --target FreeColApp`
- `swift run FreeColProtocolCLI`
- `swift test`
