# FreeCol Client — Gesamtübersicht

## Stand

Der Swift-Client deckt Login, Lobby und In-Game-Sitzungen ab und enthält eine
umfangreiche SwiftUI-Oberfläche für Karte, Einheiten, Kolonien, Europa/Markt,
Diplomatie, Native-Siedlungen und Berichte. Die Spielaktionen und XML-
Änderungen werden durch CLI-Regressionen und XCTest abgedeckt.

Die Java-Server-E2E-Prüfungen bestätigen bereits Handshake, Login,
Pre-Game-Start, Bewegung und Zugwechsel. Die erweiterten Smoke-, Deep- und
Gameplay-Probes liefen im isolierten Probe-Modus jeweils mit 1/0. Ein echter
Kauf und Verkauf von 100 Waren wurde inklusive Cargo- und Goldupdates bestätigt;
eine Koloniegründung wurde mit Name, Owner und Tile im Modell verifiziert. Der
Gameplay-Harness erzwingt beide Aktionen; die Kolonie wird außerdem nach der
Gründung erfolgreich umbenannt und ihr Modellupdate bestätigt. Die
Kolonieverwaltung bietet die Auswahl von Worker-Verbesserungen nun direkt aus
der geladenen Spezifikation. Europa zeigt und erzwingt verfügbare Markt- und
Carrier-Mengen vor Käufen/Verkäufen.

## Aktuelle Schwerpunkte

1. Weitere zentrale Aktionen als reproduzierbare Realserver-Probes
   ergänzen.
2. Reconnect-, Reject- und Multiplayer-Randfälle anhand konkreter Befunde
   priorisieren.

## Nicht-Ziele und Grenzen

- Save/Load besitzt in der verwendeten FreeCol-Version keinen passenden
  Client-Protokollfluss.
- Ein Metaserver-Browser ist nicht Teil der aktuellen Roadmap.
- Das Swift-Modell bildet weiterhin nur den vom Client benötigten Teil der
  vollständigen Java-Spielregeln und Spezifikation ab.
