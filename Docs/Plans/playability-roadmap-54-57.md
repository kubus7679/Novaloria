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

Erweiterte Parität und Realserver-Validierung siehe die abgeschlossenen Phasen
58–63 unten.

## Erweiterte Parität und Realserver-Validierung

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

## Phase 62 — Java-Server-E2E ✅

- `Tools/e2e-java-server.sh` + Smoke-/Deep-Probes; beide 131/0 gegen den
  echten Java-Server. Siehe `phase62-java-server-e2e-plan.md`.

## Phase 63 — Gameplay-E2E ✅

- Dritte Probe: Markt-Kauf/-Verkauf mit Modell-Assertions, bedingte
  Koloniegründung, Einheit bewegen + Zug beenden gegen den echten Server.
  Smoke/Deep/Gameplay jeweils 1/0 im isolierten Probe-Modus; Bewegung und
  Zugwechsel wurden ausgeführt. Koloniegründung bleibt szenarioabhängig.
  Siehe `phase63-gameplay-e2e-plan.md`.

## Phase 64 — Markttransaktion-E2E ✅

- Der Harness startet den isolierten Server mit Easy-Difficulty und die
  Gameplay-Probe setzt die Segelzeit für den Testlauf auf eine Runde.
- Der Carrier fährt nach Europa; die Probe kauft und verkauft 100 Waren und
  bestätigt Cargo-/Gold-Modellupdates.
- Smoke/Deep/Gameplay jeweils 1/0. Siehe
  `phase64-market-trade-e2e-plan.md`.

## Phase 65 — Koloniegründung-E2E ✅

- Die Gameplay-Probe navigiert den Carrier bei Bedarf zur Küste und bewegt den
  `foundColony`-Colonist direkt auf ein freies, besiedelbares Landtile.
- Koloniegründung gegen Java FreeCol 0.120 mit Name-, Owner- und Tile-Assertion
  verifiziert; der Harness erzwingt den Pfad.
- Smoke/Deep/Gameplay jeweils 1/0; 66 XCTest und 132 CLI-Prüfungen grün. Siehe
  `phase65-colony-founding-e2e-plan.md`.

## Status-/Doku-Regel

Nach jeder Phase: betroffene Zeilen in `plans.md` und
`freecol-client-roadmap.md` auf den tatsächlichen Stand setzen (Teil-Erledigt
klar benennen), Tests (XCTest + CLI) ergänzen.
