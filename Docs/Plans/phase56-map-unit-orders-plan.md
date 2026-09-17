# Phase 56 — Karte/Einheiten-Orders (Implementiert)

Ziel: Karten- und Einheitenbefehle an den Java-Client angleichen: Kontextmenü,
Order-Verwaltung, Einheiten-Zyklus, End-Turn-Dialog, Europa-Reise und
Pionier-Verbesserungen auf der Karte.

## Umfang

### 1. TilePopup (Rechtsklick-Kontextmenü)
- Neues `TilePopupView`: Rechtsklick auf die Karte öffnet ein Menü mit
  Move Here, Set Destination, Clear Orders, Fortify/Sentry/Skip,
  Go To Europe, Pionier-Improvement, Build Colony, Select Tile.
- `MapView.handleRightClick` öffnet jetzt das Menü (`GameState.tileActionTileId`)
  statt sofort zu bewegen; Auswahl/Retargeting bleiben erhalten.

### 2. Clear Orders
- `canClearSelectedUnitOrders` + `clearSelectedUnitOrders()`: sendet
  `setDestination` (leer) und `changeState state=ACTIVE`.

### 3. Einheiten-Zyklus
- `selectableLocalUnits`, `selectNextUnit()`, `selectPreviousUnit()`,
  `selectAdjacentUnit(forward:onlyAwaitingOrders:)`.
- Buttons „Next" in der Order-Leiste, Einträge im Orders-Menü
  (Next/Previous/Next Needing Orders).

### 4. End-Turn-Dialog
- `unitsAwaitingOrders` + `showEndTurnDialog`; `requestEndTurn()` öffnet den
  Dialog nur, wenn Einheiten noch Befehle offen haben, sonst direktes Zugende.
- `GameView.endTurnDialog` listet die Einheiten (auswählbar) mit
  „End Turn Anyway"/„Cancel"; End-Turn-Buttons nutzen `requestEndTurn()`.

### 5. Go To Europe via `moveTo`
- `canSendSelectedUnitToEurope` + `sendSelectedUnitToEurope()` senden
  `moveTo` mit `destination` = Europa-ID (Server-High-Seas-Routing).
- `GameState.moveToMessage` als testbarer Builder.

### 6. Pionier-Verbesserungen auf der Karte
- `Unit.workLeft` und `<tileItemContainer>/<tileImprovement>` werden geparst
  (`TileImprovement`).
- `Specification.improvementTypes` (`<tile-improvement-type>`:
  `required-role`, `add-work-turns`, `natural`).
- `selectedUnitImprovementCandidates` + `changeSelectedUnitWorkImprovement(_:)`
  senden `changeWorkImprovementType` für die Einheit auf der Karte.

## Tests

- XCTest (+4, gesamt 52): Tile-Improvement-/`workLeft`-Parsing,
  Improvement-Typen aus der Spec, `moveTo`-Payload, Einheiten-Zyklus +
  Order-Clearing.
- CLI: 130 grün (kein neuer Fall nötig, `moveTo` bereits abgedeckt).

## Bekannte Grenzen

- Das Kontextmenü ist ein SwiftUI-Overlay (kein natives `NSMenu` am Cursor).
- „Go To Europe" bietet nur navalen Einheiten an (Land-Einheiten müssen auf ein
  Schiff); die endgültige Validierung bleibt serverseitig.
- Pionier-Ziel-Kachel ist immer die aktuelle Kachel der Einheit.
