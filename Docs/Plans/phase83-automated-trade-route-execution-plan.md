# Phase 83 — Automated Trade Route Execution

## Ziel

Implement automatic execution of trade routes: move assigned carriers along their routes, load/unload goods at stops according to the route definition, and advance the route stop counter.

## Umsetzung

- [x] Add `executeTradeRoutes()` in GameState that processes all assigned trade routes
- [x] For each route with an assigned carrier:
  - Move carrier toward the next colony/Europe stop, resolving location IDs to map tiles
  - At each stop: unload goods not selected for that stop, then load selected goods
    from colony stock or Europe within cargo, availability, and market limits
  - Advance `currentStop` only after queuing the stop's cargo actions
  - Handle route looping (return to first stop after last)
- [x] Await automatic route actions before sending the end-turn request
- [x] Add UI toggle for automatic route execution
- [x] Handle edge cases: carrier not at stop, insufficient goods, full cargo

## Validierung

- `swift build --target Novaloria` erfolgreich
- `swift test`: 74 Tests erfolgreich
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich
- `Tools/e2e-java-server.sh` deckt die automatische Routen-Ausführung derzeit nicht als eigenen Probe-Schritt ab; Java-E2E dafür bleibt offen.
