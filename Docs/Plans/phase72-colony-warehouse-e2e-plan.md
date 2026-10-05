# Phase 72 — Colony Warehouse Settings E2E

## Ziel

Validate the colony warehouse/custom-house settings action against Java FreeCol
and confirm the returned settings in the client model.

## Umsetzung

- [x] After founding and renaming a colony, send a `<setGoodsLevels>` request
      containing one `<exportData>` child.
- [x] Verify the updated export toggle and import/export/low/high levels on the
      colony model.
- [x] Fail the gameplay probe if Java rejects the request or the update is
      missing.

## Validierung

- `swift build --target FreeColApp` erfolgreich.
- `swift test`: 69 Tests erfolgreich.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; Gameplay
  bestätigt Gründung, Rename, Warehouse-Update und 100 Pferde Kauf/Verkauf.
