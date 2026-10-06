# Phase 75 — Trade Route Save Validation

## Ziel

Warn about trade routes that Java FreeCol will reject before sending
`updateTradeRoute`.

## Umsetzung

- [x] Require a name, local ownership and at least two valid owned stops.
- [x] Require known cargo types and cargo at at least one stop.
- [x] Enforce the standard-route rule that a goods type cannot be present at
      every stop unless `model.option.enhancedTradeRoutes` is enabled.
- [x] Disable Save and show a validation message until the route is valid.
- [x] Recheck the route in `GameState.saveTradeRoute` before sending.

## Validierung

- `swift build --target FreeColApp` erfolgreich.
- `swift test`: 71 Tests erfolgreich, einschließlich Java-kompatibler
  Trade-Route-Validierungsfälle.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; gültige
  Create/Update/Delete-Route bleibt gegen Java erfolgreich.
