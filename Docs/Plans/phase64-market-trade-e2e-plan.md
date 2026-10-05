# Phase 64 — Markttransaktion-E2E gegen den Java-Server (Implementiert)

## Ziel

Die Phase-63-Probe soll Kauf und Verkauf von Waren tatsächlich gegen den
Java-Server ausführen. Der aktuelle Standardstart platziert den Caravel samt
Passagieren auf der Karte; die bisherige Probe überspringt den Handel, wenn kein
Carrier bereits in Europa steht.

## Umsetzung

- Der Docker-Harness startet den isolierten Java-Server auf Easy-Difficulty,
  sodass der Spieler Startgold erhält. Die Gameplay-Probe setzt
  `turnsToSail=1` über `updateGameOptions`.
- Ein eigener naval carrier wird per `moveTo` nach Europa geschickt. `loadGoods`
  dient als autoritativer Arrival-Check; ein Serverfehler „Not at a trade
  location“ lässt die Probe eine weitere servergesteuerte Runde abwarten.
- Falls der Carrier keine freie Frachtkapazität hat, werden seine Passagiere in
  Europa ausgeschifft.
- Warenmenge und Goods Type werden aus Gold, Preis, Lagerbestand und Boykott-
  Status ermittelt; Kauf und Verkauf bestätigen Cargo- und Gold-Modellupdates.
- Der Harness setzt `REAL_SERVER_REQUIRE_MARKET_TRADE=1`; ein übersprungener
  Marktpfad schlägt damit fehl.
- `FREECOL_CLI_REAL_SERVER_ONLY=1` isoliert Realserver-Probes von den lokalen
  Mock-Integrationstests; diese laufen separat über SwiftPM/CLI.

## Abgrenzung

- Die Standard-Gameplay-Probe für Bewegung und Zugwechsel bleibt erhalten.
- Koloniegründung wird separat weiterverfolgt: Dafür muss eine Colonist-Einheit
  auf ein freies, besiedelbares Landtile gelangen.
- Keine Änderungen am Java-Server oder an dessen Spielregeln.

## Validierung

- `swift build --target FreeColApp`
- `swift test`
- `swift run FreeColProtocolCLI`
- Lokale Regressionen: 66 XCTest und 130 CLI-Prüfungen bestanden.
- `Tools/e2e-java-server.sh`: Smoke/Deep/Gameplay jeweils 1/0 im isolierten
  Realserver-Modus.
- Gameplay: tatsächlich 100 `model.goods.horses` gekauft und verkauft; die
  marktbedingten Cargo-/Goldupdates wurden bestätigt.
- Koloniegründung bleibt ein separater nächster Schritt: im verwendeten
  Startspielstand stand kein Colonist auf einem freien besiedelbaren Tile.
