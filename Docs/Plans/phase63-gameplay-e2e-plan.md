# Phase 63 — Gameplay-E2E gegen den Java-Server

Ziel: Nach Login/Launch (Phase 62) echte Gameplay-Aktionen gegen den echten
Java-Server verifizieren und deren serverseitige Modelländerungen im Swift-Modell
prüfen.

## Umfang

### Gameplay-Probe (`REAL_SERVER_GAMEPLAY_E2E=1`)
- Login im Pre-Game, `ready` + `requestLaunch`, Message-Loop starten.
- Warten, bis das gestartete Spiel beim Client ankommt
  (`currentPlayerId != nil`, Einheiten vorhanden, max. 30s).
- Spec-/Karten-Assertions: Unit-, Goods-, Building- und Tile-Typen sowie
  Kacheln vorhanden.
- Lokalen Spieler über den Login-Namen auflösen.
- Markt-Daten aus dem echten Serverzustand prüfen; der Carrier fährt bei Bedarf
  nach Europa. 100 bezahlbare, nicht boykottierte Waren kaufen und wieder
  verkaufen; Cargo und Gold müssen jeweils serverseitig aktualisiert werden.
- Wenn ein Colonist mit `foundColony`-Fähigkeit auf einem freien, besiedelbaren
  Landtile verfügbar ist, optional ausschiffen und eine Kolonie gründen. Nach
  einem begonnenen Aktionsversuch sind Serverfehler Testfehler; nur fehlende
  Szenario-Voraussetzungen dürfen den Schritt überspringen.
- Eine **direkt auf einer Kachel stehende** Einheit mit Bewegung wählen
  (nicht eingeschifft, nicht in Europa).
- Bis zu acht Richtungen per `move`-`ask` probieren, bis der Server eine
  akzeptiert; danach auf die Modell-Aktualisierung der Position warten.
- `endTurn`-`ask` und warten, bis der Rundenzehler steigt (max. 60s).

### Harness
- `Tools/e2e-java-server.sh` führt jetzt drei Probes auf je frischem Server
  aus: Smoke, Deep, Gameplay.

### Gefundene/behobene Punkte
- Erste Einheiten-Auswahl traf eine eingeschiffte Einheit
  (`MOVE_NO_ACCESS_EMBARK`). Auswahl filtert jetzt auf
  `location` == Kachel-ID.
- `await`-Ausdruck in `while`-Bedingung war ungültig; Zustand wird nun im
  Schleifenkörper gelesen.
- E2E-Auswahl für Koloniegründung nutzt nun geparste `foundColony`-Fähigkeit
  samt geparsten Tile-Flags `is-water`/`can-settle`; ungültige See-/Siedlungstiles
  werden vor dem Serveraufruf ausgeschlossen.
- Nach Aktionen wird der neueste `client.game`-Snapshot für die Assertions und
  die folgende Bewegung verwendet.

## Validierungsstatus

- Lokale Regressionen nach der Erweiterung: `swift test` (66 Tests) und
  `swift run FreeColProtocolCLI` (130 Prüfungen) erfolgreich.
- Java-Server-E2E im isolierten Realserver-Modus: Smoke, Deep und Gameplay
  jeweils 1/0.
- Die Gameplay-Probe hat Bewegung und Zugwechsel tatsächlich ausgeführt und
  bestätigt. Sie hat außerdem 100 `model.goods.horses` in Europa gekauft und
  verkauft; Cargo und Gold wurden serverseitig aktualisiert.
- Koloniegründung wurde in Phase 65 mit verpflichtendem Harness gegen Java
  FreeCol 0.120 erfolgreich ergänzt; Details stehen in
  `phase65-colony-founding-e2e-plan.md`.

Damit sind Smoke, Deep und der erweiterte Gameplay-Transport-/Modellpfad gegen
Java FreeCol 0.120 bestätigt. Markttransaktion und Koloniegründung sind ebenfalls
gegen den Realserver verifiziert.

## Nutzung

```bash
Tools/e2e-java-server.sh
```
