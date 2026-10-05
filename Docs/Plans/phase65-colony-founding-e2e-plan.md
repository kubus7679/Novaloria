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
   Wasser-Tiles zu einer Küste navigieren und dort den Colonist ausschiffen.
   Falls die Einheit auf einem Wasser-Tile landet, den nächsten eigenen Zug
   abwarten.
3. Über `Game.neighborTileIds(of:)` ein benachbartes Landtile aus der
   Spezifikation auswählen. Kandidaten müssen `can-settle`, unbesiedelt und
   unbeansprucht sein; Tiles mit benachbarten Siedlungen werden ausgeschlossen.
4. Den Colonist auf das Kandidaten-Tile bewegen und `<buildColony>` senden.
5. Die neue Kolonie mit eigenem Owner, angefordertem Namen und Tile im
   deserialisierten Spielmodell bestätigen.
6. Für den E2E-Harness `REAL_SERVER_REQUIRE_COLONY_FOUNDING=1` aktivieren, sobald
   der vorbereitete Standardstart die Aktion deterministisch ermöglicht.

## Randfälle

- Wenn der Startcarrier keine Küste in Reichweite hat, vor dem Ausschiffen einen
  geeigneten Küsten-Tile anfahren.
- Server-Rejects nach Auswahl eines lokal gültigen Kandidaten sind Testfehler;
  Tile-Besitz und Nachbarschaft werden anhand des Serververtrags nachgeschärft.
- Die normale Movement-/Market-Probe bleibt ein eigener, weiterhin grüner Pfad.

## Aktueller Stand

- Die Gameplay-Probe sucht einen `foundColony`-Colonist im Startcarrier und
  erkundet mit dem Carrier erreichbare Wasser-Tiles auf dem Weg zu einer Küste.
- Die lokale Build-/Test-/CLI-Suite ist grün. Im aktuellen Java-Server-Lauf
  wurde die Koloniegründung mangels erreichbarem freiem Küsten-Tile übersprungen;
  der Colonist wurde nicht ausgeschifft und `<buildColony>` nicht gesendet.
- Nächster Schritt ist eine reproduzierbare Startkarte/-konstellation mit einem
  freien besiedelbaren Landtile in Reichweite. Erst danach wird
  `REAL_SERVER_REQUIRE_COLONY_FOUNDING=1` im Harness aktiviert.

## Validierung

- `swift build --target FreeColApp`
- `swift test`
- `swift run FreeColProtocolCLI`
- `Tools/e2e-java-server.sh` mit echter Koloniegründung gegen FreeCol 0.120.
