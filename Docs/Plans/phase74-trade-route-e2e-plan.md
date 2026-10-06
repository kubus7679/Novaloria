# Phase 74 — Trade Route CRUD E2E

## Ziel

Verify the in-game trade-route lifecycle against Java FreeCol: create a route,
save valid stops/cargo, then delete it and reconcile the client model.

## Umsetzung

- [x] Request a new trade route and capture the server-assigned route id.
- [x] Save an Europe/colony route with one cargo type and assert the server
      update in the client model.
- [x] Delete the route and assert it disappears from the model.
- [x] Reconcile routes when a full player snapshot omits a route that was
      deleted server-side.

## Validierung

- `swift build --target FreeColApp` erfolgreich.
- `swift test`: 70 Tests erfolgreich, inklusive Player-Snapshot-Reconciliation.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; Gameplay prüft
  zusätzlich Warehouse-Update und Trade-Route Create/Update/Delete.
