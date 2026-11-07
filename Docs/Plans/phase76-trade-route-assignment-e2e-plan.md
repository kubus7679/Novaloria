# Phase 76 — Trade Route Assignment E2E

## Ziel

Verify that a saved trade route can be assigned to a carrier and that deleting
the route clears the carrier assignment in the client model.

## Umsetzung

- [x] Assign the saved two-stop route to a local map carrier.
- [x] Confirm the server update sets the carrier's `tradeRoute` id.
- [x] Delete the route and confirm both the route and carrier assignment are
      removed from the client model.
- [x] Reconcile full player snapshots so deleted routes do not remain stale.

## Validierung

- `swift build --target Novaloria` erfolgreich.
- `swift test`: 71 Tests erfolgreich.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; Gameplay prüft
  route create/update/assign/delete gegen Java FreeCol 0.120.
