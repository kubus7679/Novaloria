# Phase 66 — Colony Worker Improvement Picker

## Ziel

Die Kolonieverwaltung soll für Arbeitsverbesserungen keine FreeCol-Protokoll-IDs
mehr erfordern. Spieler wählen einen Improvement-Typ aus den geladenen
Spezifikationsdaten.

## Umsetzung

- [x] Nicht-natürliche Tile-Improvements als Kandidaten aus der Spezifikation
      anbieten.
- [x] Das Roh-ID-Textfeld im Kolonie-Panel durch einen Picker ersetzen.
- [x] Die Auswahl initialisieren und den Aktionsbutton deaktivieren, wenn kein
      Kandidat oder kein Worker ausgewählt ist.
- [x] Bestehende `changeWorkImprovementType`-Aktion und Server-Payload beibehalten.

## Validierung

- `swift build --target Novaloria` erfolgreich.
- `swift test`: 66 Tests erfolgreich.
- `swift run FreeColProtocolCLI`: 132 Prüfungen erfolgreich; darunter die
  bestehende Regression für das `changeWorkImprovementType`-Payload.

Die Änderung betrifft nur die Auswahloberfläche; das bestehende Aktionsprotokoll
bleibt unverändert.
