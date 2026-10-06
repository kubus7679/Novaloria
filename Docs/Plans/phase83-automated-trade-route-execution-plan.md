# Phase 83 — Automated Trade Route Execution

## Ziel

Implement automatic execution of trade routes: move assigned carriers along their routes, load/unload goods at stops according to the route definition, and advance the route stop counter.

## Umsetzung

- [x] Add `executeTradeRoutes()` in GameState that processes all assigned trade routes
- [x] For each route with an assigned carrier:
  - Move carrier to next stop if not already there
  - At each stop: unload goods specified in cargo, load goods specified in cargo
  - Advance currentStop counter
  - Handle route looping (return to first stop after last)
- [x] Add `executeTradeRoutesOnTurnEnd()` hook called at turn end
- [x] Add UI toggle for automatic route execution
- [x] Handle edge cases: carrier not at stop, insufficient goods, full cargo

## Validierung

- `swift build --target FreeColApp` erfolgreich
- `swift test`: 74 Tests erfolgreich
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0; automatische Routenausführung gegen Java verifiziert