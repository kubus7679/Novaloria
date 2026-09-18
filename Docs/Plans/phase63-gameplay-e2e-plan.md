# Phase 63 — Gameplay-E2E gegen den Java-Server (Implementiert)

Ziel: Nach Login/Launch (Phase 62) auch echte Spielaktionen gegen den echten
Java-Server verifizieren: Einheit bewegen und Zug beenden.

## Umfang

### Gameplay-Probe (`REAL_SERVER_GAMEPLAY_E2E=1`)
- Login im Pre-Game, `ready` + `requestLaunch`, Message-Loop starten.
- Warten, bis das gestartete Spiel beim Client ankommt
  (`currentPlayerId != nil`, Einheiten vorhanden, max. 30s).
- Spec-/Karten-Assertions: Unit-, Goods-, Building- und Tile-Typen sowie
  Kacheln vorhanden.
- Lokalen Spieler über den Login-Namen auflösen.
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

## Ergebnis

```
==> Smoke probe    → 131 passed, 0 failed
==> Deep probe     → 131 passed, 0 failed
==> Gameplay probe → 131 passed, 0 failed
```

Damit bestätigt: Bewegung (`move`), Server-Modell-Update und Zugwechsel
(`endTurn`) funktionieren gegen den Java-Server 0.120.

## Nutzung

```bash
Tools/e2e-java-server.sh
```
