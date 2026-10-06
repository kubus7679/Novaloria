# Phase 59 — Europe-Tiefe (Implementiert)

Ziel: Europa von Rekrutierung über Einheitenkauf, Fracht/Dump bis zum
Preisverlauf vollständig bedienbar machen.

## Umfang

### 1. Einheiten kaufen (PurchasePanel)
- `purchasableEuropeUnits` aus `<unitPrice unitType price>` (nach Preis
  sortiert), `unitDisplayName(_:)`.
- Neue „Purchase Units"-Sektion mit „Buy" → `trainUnitInEurope(unitType:)`
  (nur Gold-Prüfung; kein Rekruten-Tracking mehr).

### 2. Rekrutierung (RecruitPanel)
- `recruitUnitInEurope(slot:)` sendet `emigrateUnit` mit 1-basiertem Slot
  (0 = zufällig); zählt `purchasesRecruits`/`purchasesTotal`.
- Recruit-Sektion nutzt die Slots statt fälschlich `trainUnitInEurope`.

### 3. Fracht / Dump
- `Unit` parst `<goodsContainer>` (getragene Waren).
- `selectedUnitCargoGoods` + `dumpSelectedUnitCargo(typeId:amount:)`
  (`unloadGoods`), lokaler Spiegel `Game.removeUnitGoods`.
- „Dump …"-Buttons in den Einheiten-Quick-Actions.

### 4. Marktverlauf
- `recordMarketSnapshot()` zeichnet Kauf- und Verkaufspreise je Ware synchron
  auf (max. 60 Punkte, nur bei Änderung); aufgerufen aus Client-Bridge-Updates.
- Europe-Panel zeigt beide Reihen als farblich getrennte Linien mit Last/Min/Max.
- Implementierung: `phase80-market-price-history-plan.md`.

## Tests

- XCTest (+3, gesamt 62): Fracht-Parsing/`removeUnitGoods`,
  kaufbare Einheiten + Rekrut-Tracking, Marktverlaufs-Aufzeichnung.
- CLI: 130 grün.

## Bekannte Grenzen

- Der Preisgraph ist ein einfacher Verlauf aus Client-Snapshots (kein
  Java-`MarketPanel`-Graph mit Achsen/Zeitachse).
- Ein separates Dock-Drag&Drop gibt es nicht; Ein-/Ausladen erfolgt über die
  vorhandenen Load/Unload-Aktionen und den Dump-Button.
