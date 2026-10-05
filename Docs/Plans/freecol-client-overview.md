# FreeCol Client — Gesamtübersicht

## Stand

Der Swift-Client deckt Login, Lobby und In-Game-Sitzungen ab und enthält eine
umfangreiche SwiftUI-Oberfläche für Karte, Einheiten, Kolonien, Europa/Markt,
Diplomatie, Native-Siedlungen und Berichte. Die Spielaktionen und XML-
Änderungen werden durch CLI-Regressionen und XCTest abgedeckt.

Die Java-Server-E2E-Prüfungen bestätigen bereits Handshake, Login,
Pre-Game-Start, Bewegung und Zugwechsel. Die erweiterten Smoke-, Deep- und
Gameplay-Probes liefen jeweils mit 131/0. Markttransaktion und Koloniegründung
wurden in diesem Lauf wegen fehlender Voraussetzungen des generierten Spiels
übersprungen; die Aktionspfade bleiben für eine passende Startkonstellation
offen.

## Aktuelle Schwerpunkte

1. Für Markt und Kolonie eine passende deterministische E2E-Startkonstellation
   bereitstellen und die Modellupdates gegen den Java-Server bestätigen.
2. Danach weitere zentrale Aktionen als reproduzierbare Realserver-Probes
   ergänzen.
3. Reconnect-, Reject- und Multiplayer-Randfälle anhand konkreter Befunde
   priorisieren.

## Nicht-Ziele und Grenzen

- Save/Load besitzt in der verwendeten FreeCol-Version keinen passenden
  Client-Protokollfluss.
- Ein Metaserver-Browser ist nicht Teil der aktuellen Roadmap.
- Das Swift-Modell bildet weiterhin nur den vom Client benötigten Teil der
  vollständigen Java-Spielregeln und Spezifikation ab.
