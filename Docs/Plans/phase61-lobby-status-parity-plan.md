# Phase 61 — Lobby- & Status-Parität (Implementiert)

Ziel: Den letzten Backlog-Block ohne Save/Load schließen: Lobby-Transparenz,
Options-Komfort und eine Status-/Statistikübersicht.

## Umfang

### 1. Lobby-Spielertabelle
- `GameState.lobbyPlayers` (sortiert) + Anzeige im Login-/Lobby-Screen:
  Name, Nation, Typ (Human/AI/Native/REF), Admin-Markierung, Ready-Status;
  lokaler Spieler gelb hervorgehoben.

### 2. Options-Komfort
- `GameState.serverOptionValue(id:)` liest den Server-Spiegel
  (`Game.optionValues` aus dem `updateGameOptions`-Echo).
- Presets-Menüs für Game- und Map-Generator-Optionen
  (`startingMoney`, `numPlayers`, `difficulty`, `giftToAllies`,
  `customHouse`, `mapWidth`, `mapHeight`, `landMass`, `mapGenerator`);
  Roh-Eingabe bleibt möglich.
- „Server: …"-Hinweis zeigt den autoritativen Wert der aktiven Option.

### 3. Status-/Statistikpanel
- `StatusPanelView` (Game-Menü → „Status…"): Spiel-ID, Runde, aktueller
  Spieler, Anzahl Spieler/Kolonien/Einheiten, erkundete Kacheln (%),
  Spielertabelle (Gold, Score, Einheiten, Kolonien) und lokale Kennzahlen
  (Gold, Steuer, Immigration, Liberty, Score, Founding Fathers, Events).

### 4. Codegen-Fix
- `Tools/codegen.py` erkennt jetzt auch `public final class …Message`
  (zuvor wurden `final`-Klassen still übersprungen, u. a. die
  Metaserver-Messages).

## Nicht-Ziel (dokumentiert)

- **Metaserver-Browser** (`serverList`): Der Metaserver wird über einen
  separaten Kanal abgefragt; ohne offline testbaren Pfad und mit externer
  Abhängigkeit bleibt das außen vor. Der Codegen-Fix deckt die Message
  künftig ab, falls das Feature kommt.
- **Save/Load**: weiterhin ausgeschlossen (server-seitig, kein
  Client-Protokoll; bräuchte embedded Server).

## Tests

- XCTest (+1, gesamt 66): `lobbyPlayers`-Sortierung/Admin-Flag,
  `serverOptionValue`.
- CLI: 130 grün.

## Bekannte Grenzen

- Options-Presets sind statische Vorschläge; die vollständige Options-Metadaten
  (Typen, Bereiche, Enum-Werte) liefert der Server nicht im Spec-Subset, das
  der Client parst.
