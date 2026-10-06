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
Warehouse-Grenzwerte einer gegründeten Kolonie werden ebenfalls gegen den
Java-Server geändert und im Clientmodell bestätigt. Die
Kolonieverwaltung bietet die Auswahl von Worker-Verbesserungen nun direkt aus
der geladenen Spezifikation. Handelsrouten werden gegen den Java-Server erstellt,
geändert, Carriern zugewiesen und gelöscht; der Editor prüft vor dem Speichern
die Java-Regeln. Europa
begrenzt Käufe nach Bezahlbarkeit und freiem
Frachtraum und Verkäufe nach dem Warenbestand des ausgewählten Carriers. „Max
Buy“ und „Max Sell“ füllen passende Mengen bis zur 100er-Preisstufe ein; die
Ansicht zeigt Gesamtpreis und besteuerten Verkaufserlös. Boykottierte
Waren sind bis zur Begleichung der Rückstände vom Handel ausgeschlossen. Die lokal
berechneten Marktpreise folgen jetzt auch bei verarbeiteten New-World-Gütern
der Java-Rundung.
Der Europe-Verlauf visualisiert Kauf- und Verkaufspreise getrennt mit Zugnummern.

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
