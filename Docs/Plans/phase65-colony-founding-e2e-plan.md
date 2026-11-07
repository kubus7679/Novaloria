# Phase 65 — Koloniegründung-E2E gegen den Java-Server

## Ziel

Die Phase-63-Probe erkennt Koloniegründungs-Voraussetzungen, aber der aktuelle
Serverstart platziert die Gründereinheiten eingeschifft. Diese Probe soll einen
Colonist ausschiffen, auf ein gültiges Landtile bringen und die
serverseitige Koloniegründung samt Modellupdate bestätigen.

## Umsetzungsschritte

1. Einen eigenen naval carrier mit einer Einheit mit geerbter
   `model.ability.foundColony`-Fähigkeit aus dem gestarteten Spiel auswählen.
2. Vor dem Phase-64-Europa-Trip den Carrier bei Bedarf über bekannte
   Wasser-Tiles zu einer Küste navigieren. Der Colonist bewegt sich anschließend
   direkt vom Carrier auf das benachbarte Landtile; Java-FreeCol entlädt ihn bei
   dieser Bewegung. `<disembark>` allein lässt ihn auf dem Wasser-Tile des
   Carriers und ist dafür ungeeignet.
3. Über `Game.neighborTileIds(of:)` ein benachbartes Landtile aus der
   Spezifikation auswählen. Kandidaten müssen `can-settle`, unbesiedelt und
   unbeansprucht sein; Tiles mit benachbarten Siedlungen werden ausgeschlossen.
4. Den Colonist auf das Kandidaten-Tile bewegen. Falls die Bewegung alle
   Aktionspunkte verbraucht, den nächsten eigenen Zug abwarten.
5. `<buildColony>` senden.
6. Die neue Kolonie mit eigenem Owner, angefordertem Namen und Tile im
   deserialisierten Spielmodell bestätigen.
7. Im Harness `REAL_SERVER_REQUIRE_COLONY_FOUNDING=1` setzen, damit ein
   übersprungener Gründungspfad als Fehler zählt.

## Randfälle

- Wenn der Startcarrier keine Küste in Reichweite hat, über bekannte und
  erkundbare Wasser-Tiles einen geeigneten Küsten-Tile anfahren.
- Server-Rejects nach Auswahl eines lokal gültigen Kandidaten sind Testfehler;
  Tile-Besitz und Nachbarschaft werden anhand des Serververtrags nachgeschärft.
- Die normale Movement-/Market-Probe bleibt ein eigener, weiterhin grüner Pfad.

## Aktueller Stand

- Die Gameplay-Probe findet einen `foundColony`-Colonist im Startcarrier,
  erkundet bei Bedarf bis zu 120 Schritte in Richtung eines freien Küsten-Tiles
  und bewegt den Gründer direkt auf das benachbarte Landtile.
- Java FreeCol 0.120 bestätigte die Gründung; der Client prüft Name, Owner und
  Tile der neuen Kolonie im Modell. `Game.applyUpdate` übernimmt dazu auch
  verschachtelte Units und Siedlungen in Tile-Updates.
- `Tools/e2e-java-server.sh` setzt `REAL_SERVER_REQUIRE_COLONY_FOUNDING=1`;
  der Gründungspfad kann nicht mehr still übersprungen werden.
- Aktueller Realserver-Lauf: Smoke, Deep und Gameplay jeweils 1/0; Gameplay
  gründete eine Kolonie und kaufte/verkaufte 100 Pferde in Europa.

## Validierung

- `swift build --target Novaloria`
- `swift test` (66 Tests)
- `swift run FreeColProtocolCLI` (132 Prüfungen)
- `Tools/e2e-java-server.sh` mit verpflichtender Koloniegründung gegen FreeCol 0.120.
