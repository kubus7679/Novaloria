# Phase 55 — Kolonie-Ökonomie (Implementiert)

Ziel: Den Kern-Wirtschaftsloop der Kolonie echt bedienbar und server-korrekt
machen. Zuvor waren mehrere Aktionen wirkungslos oder nur über Roh-IDs
erreichbar.

## Umfang

### 1. Custom-House / Warehouse (`<exportData>` / `setGoodsLevels`)
- `ColonyExportData` + Parsing der `<exportData>`-Kinder einer Kolonie
  (`exported`, `importLevel`, `exportLevel`, `highLevel`, `lowLevel`).
- `setGoodsLevels` wird jetzt korrekt mit einem `<exportData id=.. >`-Child
  gesendet (`GameState.exportDataMessage`). Vorher: nur `colony=` → Server-No-op.
- UI: `WarehouseSheet` (Java `WarehouseDialog`) mit Export-Toggle und
  Import/Export/Low/High-Steppern pro Ware; Button „Warehouse…" im Kolonie-Panel.

### 2. Kolonie-Arbeitsplätze (`<colonyTile>` / `rearrangeColony`)
- `ColonyWorkLocation` + Parsing der `<colonyTile>`-Kinder (`workTile`/`tile`).
  Gebäude bleiben in `buildings`.
- `assignSelectedColonyWorker(to:)` baut ein echtes `rearrangeColony` mit
  Arrangements (`xNunit/loc/work/role/count`) und tauscht einen ggf.
  vorhandenen Besetzer auf den vorherigen Platz. Vorher: `xLength=0` (No-op).
- UI: Arbeitsplatz-Picker statt „Work Location ID"-Textfeld.

### 3. Worker-Picker statt Roh-IDs
- Work-Type-Auswahl aus den Spec-Goods-Typen (`selectedColonyWorkTypeCandidates`).
- Teacher-Auswahl aus den Kolonie-Einheiten.
- Arbeitsplatz-Auswahl aus Kacheln + Gebäuden.

### 4. Marktpreise (`costToBuy` / `paidForSale`)
- `GoodsTypeInfo` um `storable`, `new-world-goods`, `made-from` und die
  `<market>`-Referenzwerte (`initial-amount`, `initial-price`,
  `price-difference`) erweitert.
- `MarketPricing.prices(...)` bildet den ersten Durchlauf von Java
  `MarketData.price()` nach (inkl. New-World-Clamp und Preisgrenzen). Phase 77
  gleicht Single-Precision-Rundung und `made-from`-New-World-Güter an. Der
  Server serialisiert nur `amount`/`initialPrice`; Preise werden lokal berechnet.
- Europe-Panel und Trade-Report zeigen Buy/Sell/Arrearsspalten.

### 5. Rückstaende (`payArrears`)
- `payArrears(goodsTypeId:)` + `canPayArrears`, Button „Pay N" pro boykottierter
  Ware im Markt.

## Tests

- XCTest (+5, gesamt 48): Marktpreis-Berechnung (inkl. New-World-Clamp),
  ExportData-/WorkTile-Parsing, `setGoodsLevels`- und `rearrangeColony`-Payload.
- CLI: bestehender Kolonie-Action-Test prüft jetzt die vollen Payloads
  (`<exportData>`-Child bzw. `x0unit/loc/role`).

## Bekannte Grenzen

- `MarketPricing` repliziert nur den ersten Preisdurchlauf; die server-seitige
  Clamping-Historie (`costToBuy`-Vorwert) wird nicht simuliert.
- Die Reihenfolge der Arbeitsslots (Tile-Ertrag pro Slot) wird weiterhin nicht
  einzeln modelliert; die Auswahl erfolgt über Work-Location-IDs.
- Automatische Neuverteilung aller Kolonisten (Java `scratch colony`-Diff) ist
  nicht implementiert; getauscht wird gezielt der gewählte Arbeiter + Besetzer.
