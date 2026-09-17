# Playability Roadmap (Phasen 54–57) — Offene Arbeit

Diese Datei korrigiert den bisherigen Eindruck, die Roadmap sei vollständig
abgearbeitet. Die bestehenden `[x]`-Markierungen in `plans.md` und
`freecol-client-roadmap.md` bedeuten „protokoll-/UI-seitig angebunden", **nicht**
„wie im Java-Client spielbar". Eine systematische Gegenprüfung gegen
`/Users/marcel/projects/freecol` (104/104 Message-Tags vorhanden, ~60 von ~70
`ServerAPI`-Actions) ergab die unten gelisteten Lücken.

## Phase 54 — Inbound-Blocker ✅ (siehe `phase54-inbound-blockers-plan.md`)

## Phase 55 — Kolonie-Ökonomie (offen, P0/P1)

- [ ] Kolonie-`<exportData>` parsen und `setGoodsLevels` mit ExportData-Child
      senden; Warehouse-Dialog (Export/Import-Level pro Ware). Aktuell sendet
      `setSelectedColonyGoodsLevels` nur `colony=` → Server-No-op.
- [ ] Kolonie-`<workLocation>` parsen; `rearrangeColony` mit echter
      Arrangement-Liste (aktuell `xLength=0`).
- [ ] Roh-ID-Felder in `ColonyPanelView` (`WorkType ID`, `Teacher ID`,
      `Work Location ID`) durch Picker ersetzen.
- [ ] Marktpreise: `costToBuy`/`paidForSale` aus `amount`+`initialPrice`
      berechnen statt `initialPrice` für beide Richtungen.
- [ ] `payArrears` (Boykott-Aufhebung) verdrahten.

## Phase 56 — Karte/Einheiten-Orders (offen, P1)

- [ ] `moveTo` (Server-Pathfinding) senden statt händischer Einzelschritte.
- [ ] „Clear Orders", Next-Unit-Zyklus, EndTurn-Dialog mit unversorgten
      Einheiten.
- [ ] Rechtsklick-`TilePopup` (Kontextmenü) — hinter dem NSView-Capture.
- [ ] Pionier-Improvement auf Kartenkacheln (`changeWorkImprovementType` außerhalb
      der Kolonie); Unit-`<workImprovement>`/`workLeft` parsen.

## Phase 57 — Founding Fathers & Reports (offen, P1)

- [ ] FF-Daten parsen (`foundingFathers`, `offeredFathers`, `currentFather`);
      Continental-Congress-Report.
- [ ] Fehlende Reports: Labour (+Detail), Religious, Production, Education,
      Requirements, History.
- [ ] `modelMessage` parsen + Event-Log/Turn-Report (statt 8-Zeilen-Chat-Puffer).
- [ ] `highScores`/`nationSummary` Request-Actions.
- [ ] Colopedia um Terrain/Gebäude/Fathers/Nations erweitern.

## Backlog (nach Spielbarkeit)

- **58** Diplomatie/Native-Tiefe: aktive Diplomatie einleiten, IndianSettlement-
  Panel, `askSkill`/`learnSkill`-UI, FirstContact/NativeDemand/Monarch/PreCombat-
  Dialoge, `tension`/`bannedMissions`.
- **59** Europe-Tiefe: `PurchasePanel`, Dock/Cargo/Dump, Auswanderungs-Auswahl,
  Transaktions-Log/Preisgraph.
- **60** Model-Tiefe: `featureChange` (Fähigkeiten/Modifier/History),
  Einheiten-`goodsContainer`, Tile-`tileItemContainer` (Ressourcen/Lost-City),
  NationOptions/Areas/Cibola.
- **61** Meta (optional): Save/Load nur mit embedded Server (Design nötig),
  Meta-Server-Browser, Lobby-Optionsbaum.

## Status-/Doku-Regel

Nach jeder Phase: betroffene Zeilen in `plans.md` und
`freecol-client-roadmap.md` auf den tatsächlichen Stand setzen (Teil-Erledigt
klar benennen), Tests (XCTest + CLI) ergänzen.
