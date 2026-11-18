# Novaloria Atlas Graphics Mod Plan

## Ziel

Ein eigenständiges, installierbares FreeCol-Grafikmod mit originellen, farbigen
Illustrationen und Resource-Mappings für Terrain, Waren, Einheiten und Gebäude.
Novaloria soll die enthaltenen Gebäude-Icons zusätzlich in der Colopedia laden.

## Etappe 1

- [x] FreeCol-Mod-Metadaten und Generator-Einstieg für vier Kategorien anlegen.
- [x] Einen nativen macOS-Generator für reproduzierbare PNG-Assets und ZIP ergänzen.
- [x] Die Colopedia um den Mod-Fallback `image.buildingicon.*` erweitern.
- [x] Mod-Mapping und Gebäude-Fallback mit fokussierten Tests absichern.
- [x] Paket erzeugen, Mod-Inhalt validieren und Swift-Tests ausführen.

## Ergebnis Etappe 1

- 127 PNGs und Resource-Mappings erzeugt; das ZIP-Archiv besteht `unzip -t`.
- Der gezielte Gebäude-Icon-XCTest besteht.
- Die ersten 115 Tests der Gesamtsuite bestehen. `InteractionRepairTests.testDestinationChangesAndCancellationRequireServerConfirmation`
  meldet vier Assertion-Fehler; danach liefert der XCTest-Prozess keine weiteren
  Ergebnisse und wurde als hängend beendet.

## Gestaltungsrahmen

- Eigenständige Atlas-Illustrationen; keine extrahierten oder nachgezeichneten
  Civilization-VII-Assets.
- Transparente Icons für Waren, Einheiten und Gebäude; rautenförmige Terrainkacheln.
- FreeCol-IDs und vorhandene Resource-Keys bleiben unverändert.

## Etappe 2 — Atlas-Illustrationen (verworfen)

Verworfen: Das Repackaging der FreeCol-Originale ersetzt keine Grafiken und vergrößert
Einheiten im Java-Client dreifach. Nachfolger: `2026-11-18-wtp-stil-grafikmod-plan.md`.

- [x] Die WtP-Referenz auf gerenderte Einheiten, isometrische Gebäude und
  strukturierte Terrainflächen übertragen, ohne WtP-Dateien zu kopieren.
- [x] Die vorhandenen, GPL-lizenzierten FreeCol-Renderbilder als hochwertige
  Motivbasis verwenden und farblich/hinsichtlich Auflösung harmonisieren.
- [x] Alle vier Kategorien neu paketieren und visuell prüfen.
- [x] ZIP neu erzeugen und Gebäude-Fallback-XCTest sowie Diff-Check ausführen.

## Ergebnis Etappe 2

- 127 vorhandene FreeCol-Renderbilder werden passend zu den IDs ausgewählt,
  leicht farbkorrigiert und mit 3× Auflösung in das Mod übernommen.
- Das Mod-ZIP enthält die FreeCol-GPL-Lizenzdatei; WtP-Assetdateien werden nicht
  übernommen.
- ZIP-Integrität, Gebäude-Fallback-XCTest und `git diff --check` sind erfolgreich.