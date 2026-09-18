# Playability Roadmap (Phasen 54–57) — Offene Arbeit

Diese Datei korrigiert den bisherigen Eindruck, die Roadmap sei vollständig
abgearbeitet. Die bestehenden `[x]`-Markierungen in `plans.md` und
`freecol-client-roadmap.md` bedeuten „protokoll-/UI-seitig angebunden", **nicht**
„wie im Java-Client spielbar". Eine systematische Gegenprüfung gegen
`/Users/marcel/projects/freecol` (104/104 Message-Tags vorhanden, ~60 von ~70
`ServerAPI`-Actions) ergab die unten gelisteten Lücken.

## Phase 54 — Inbound-Blocker ✅ (siehe `phase54-inbound-blockers-plan.md`)

## Phase 55 — Kolonie-Ökonomie ✅ (siehe `phase55-colony-economy-plan.md`)

- [x] `<exportData>` geparst; `setGoodsLevels` sendet ExportData-Child;
      `WarehouseSheet` mit Export-Toggle und Levels pro Ware.
- [x] `<colonyTile>`-Arbeitsplätze geparst; `rearrangeColony` mit echter
      Arrangement-Liste inkl. Besetzer-Tausch.
- [x] Roh-ID-Felder durch Picker ersetzt (Work Type, Teacher, Work Location).
- [x] Marktpreise `costToBuy`/`paidForSale` via `MarketPricing` berechnet.
- [x] `payArrears` verdrahtet.

## Phase 56 — Karte/Einheiten-Orders ✅ (siehe `phase56-map-unit-orders-plan.md`)

- [x] Rechtsklick-`TilePopup` als Overlay-Kontextmenü.
- [x] „Clear Orders", Next-/Previous-Unit-Zyklus, End-Turn-Dialog.
- [x] „Go To Europe" via `moveTo` (Server-High-Seas-Routing).
- [x] Pionier-Improvement auf Kartenkacheln; `workLeft`/`<tileImprovement>`
      und Spec-Improvement-Typen geparst.

## Phase 57 — Founding Fathers & Reports ✅ (siehe `phase57-founding-fathers-reports-plan.md`)

- [x] FF-Daten geparst (`foundingFathers`, `offeredFathers`, `currentFather`);
      Continental-Congress-Report.
- [x] Reports: Labour, Religious, Production, Education, Requirements, History.
- [x] `modelMessage` geparst + Event-Log/Turn-Report.
- [x] `highScores`/`nationSummary` Request-Actions.
- [x] Colopedia um Terrain/Gebäude/Improvements/Fathers/Nations erweitert.

## Playability-Phasen 54–57 abgeschlossen

Backlog siehe unten (58–61).

## Backlog (nach Spielbarkeit)

- **58** Diplomatie/Native-Tiefe ✅: aktive Diplomatie (PROPOSE_TRADE),
  IndianSettlement-Details, `askSkill`/`learnSkill`-UI, PreCombat-Bestätigung,
  `tension`/`bannedMissions`. Siehe `phase58-diplomacy-native-depth-plan.md`.
- **59** Europe-Tiefe ✅: `PurchasePanel`, Rekrutierungs-Slots, Cargo/Dump,
  Marktverlauf. Siehe `phase59-europe-depth-plan.md`.
- **60** Model-Tiefe ✅: `featureChange` (Fähigkeiten/ModelMessages),
  Einheiten-`goodsContainer` (Phase 59), Tile-Ressourcen/Lost-City,
  NationOptions/Cibola. Siehe `phase60-model-depth-plan.md`.
- **61** Meta ✅ (ohne Save/Load): Lobby-Spielertabelle, Options-Presets +
  Server-Echo, Status-/Statistikpanel, Codegen-Fix für `final`-Messages.
  Metaserver-Browser und Save/Load bleiben Nicht-Ziele. Siehe
  `phase61-lobby-status-parity-plan.md`.

## Status-/Doku-Regel

Nach jeder Phase: betroffene Zeilen in `plans.md` und
`freecol-client-roadmap.md` auf den tatsächlichen Stand setzen (Teil-Erledigt
klar benennen), Tests (XCTest + CLI) ergänzen.
