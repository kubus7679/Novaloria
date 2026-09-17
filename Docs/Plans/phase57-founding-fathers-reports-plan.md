# Phase 57 — Founding Fathers & Reports (Implementiert)

Ziel: Fortschritts- und Berichtsoberflächen vervollständigen: Founding-Father-
Daten, fehlende Java-Reports, Event-Log und Server-Abfragen.

## Umfang

### 1. Founding Fathers
- `Player` parst `currentFather` (Attribut), `<foundingFathers>` und
  `<offeredFathers>` (`xLength`/`xN`-Listen).
- `GameState.localPlayerFoundingFathers/OfferedFathers/CurrentFather`,
  `foundingFatherDisplayName(_:)`, `nonisolated foundingFatherLabel(_:)`.
- Neuer Report **Continental Congress**: laufende Wahl, Väter im Kongress,
  angebotene Väter.

### 2. Fehlende Reports
`ReportKind` um sieben Einträge erweitert (jetzt 19):
- **Labour**: pro Kolonie die Arbeiter (Einheit, Work Type, Location).
- **Religious**: Missionare und bekannte native Siedlungen.
- **Production**: geschätzte Nettoproduktion pro Kolonie.
- **Education**: Student/Teacher-Zuweisungen.
- **Requirements**: Bauziel + Materialbedarf je Kolonie.
- **History**: Event-Log (siehe 3).
- **Continental Congress** (siehe 1).
- Neue `GameState`-Helfer: `localColonies`, `colonyWorkerUnits`,
  `colonyProductionSummary`, `colonyBuildRequirements`, `educationAssignments`,
  `missionaryUnits`.

### 3. Event-Log / Turn-Report
- `ModelMessage` (`id`, `source`, `display`, `messageType`, `hasBeenDisplayed`)
  wird aus `<modelMessage>`-Kindern geparst; `label` entfernt das
  `model.message.`-Präfix.
- `GameState.localPlayerModelMessages`; der Turn-Report zeigt die letzten
  Events, der History-Report alle.

### 4. Server-Abfragen
- `requestHighScores(key:)` (Default `model.option.score`) und
  `requestNationSummary(playerId:)` senden `highScores`/`nationSummary` als
  `ask` und übernehmen die Antwort.
- High-Scores-Report hat einen „Request from Server"-Button; der Foreign-Report
  einen Nation-Summary-Bereich (Auswahl + Anzeige).

### 5. Colopedia
- Zusätzliche Abschnitte: Terrain (Zentralkachel-Output), Buildings
  (Population/Upkeep/Kosten), Tile Improvements (Work Turns/Rolle),
  Founding Fathers (lokaler Spieler) und Nations.

## Tests

- XCTest (+4, gesamt 56): FF-/`modelMessage`-Parsing, Report-Helfer
  (Arbeiter/Education/Missionare, Build-Requirements), FF-Label.
- CLI: 130 grün.

## Bekannte Grenzen

- Die `modelMessage`-Texte sind i18n-Keys; ohne Message-Bundle wird der Key
  (bzw. `display`) angezeigt, kein lokalisierter Satz.
- Der Continental-Congress-Fortschritt (Glocken/Liberty) wird nicht als
  Prozentbalken dargestellt; es werden die bekannten Väter gelistet.
