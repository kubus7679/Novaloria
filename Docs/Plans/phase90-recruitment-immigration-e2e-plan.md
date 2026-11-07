# Phase 90 — Rekrutierung & Einwanderung-E2E-Validierung

## Ziel

Dedizierte End-to-End-Validierung der Rekrutierungs- und Einwanderungs-Aktionen im Europa-Bildschirm gegen den Java FreeCol Server. Die Probe sendet echte `recruitUnit`, `emigrateUnit` und `purchaseUnit` Aktionen, erfasst Antworten und prüft Modelländerungen (Gold, Einheiten, Cargo).

## Kontext

### Aktueller Stand

| Feature | Phase | Protokoll | UI | Java-E2E |
|---------|-------|-----------|-----|----------|
| Einheit in Europa rekrutieren (`recruitUnit`) | 3/59 | ✅ | ✅ | ❌ |
| Einwanderer auswählen (`emigrateUnit`) | 3/59 | ✅ | ✅ | ❌ |
| Einheit in Europa kaufen (`purchaseUnit`) | 3/59 | ✅ | ✅ | ❌ |
| Fracht in Europa laden/entladen | 3/59 | ✅ | ✅ | ❌ |

### Java-Server-Verhalten (Wire-Protokoll)

**Einheit rekrutieren:**
```xml
<!-- Client rekrutiert Einheit in Europa -->
<recruitUnit unit="unit-123"/>
<!-- Server: Gold abgezogen, Einheit erscheint in Europa -->
<update>
  <player id="player-1" gold="400"/>
  <unit id="unit-123" unitType="model.unit.freeColonist" location="europe:7" owner="player-1"/>
</update>
```

**Einwanderer auswählen:**
```xml
<!-- Client wählt Einwanderer aus Rekrutierungs-Pool -->
<emigrateUnit unit="unit-456"/>
<!-- Server: Einheit wechselt von Pool zu Spieler -->
<update>
  <unit id="unit-456" unitType="model.unit.veteranSoldier" location="europe:7" owner="player-1"/>
  <remove divert="unit-456"/> <!-- aus Pool entfernt -->
</update>
```

**Einheit kaufen:**
```xml
<!-- Client kauft Einheit direkt -->
<purchaseUnit unit="unit-789"/>
<!-- Server: Gold abgezogen, Einheit in Europa -->
<update>
  <player id="player-1" gold="200"/>
  <unit id="unit-789" unitType="model.unit.caravel" location="europe:7" owner="player-1"/>
</update>
```

**Fracht auf Schiff laden:**
```xml
<!-- Client lädt Güter auf Schiff in Europa -->
<loadCargo unit="ship-1" goods="model.goods.tools" amount="100"/>
```

### Offene Lücken

1. Keine Validierung, dass der Java-Server Rekrutierungs-Aktionen akzeptiert
2. Keine Validierung der Gold-Abzüge bei Rekrutierung/Kauf
3. Keine Validierung der Einheiten-Erstellung in Europa
4. Keine Validierung der Einwanderer-Auswahl (Pool → Spieler)
5. Keine Validierung von Cargo-Load/Unload in Europa

## Umsetzung

### 1. Neue Probe: `REAL_SERVER_RECRUITMENT_E2E`

**Datei:** `Sources/FreeColProtocolCLI/main.swift`

**Ablauf:**

1. Verbindung, Login, Spielstart (Easy)
2. Warten auf IN_GAME
3. **Carrier nach Europa segeln:** Wie in Market-E2E (Phase 64)
4. **In Europa ankommen:** Warten bis Carrier in Europa (`location` = `europe:X`)
5. **Rekrutierung testen:**
   - Verfügbare Rekrutierungs-Slots prüfen (via `europe` in Player)
   - `recruitUnit` für freien Slot senden
   - Gold-Abzug und neue Einheit in Europa verifizieren
6. **Einwanderung testen:**
   - Verfügbare Einwanderer im Pool prüfen
   - `emigrateUnit` senden
   - Einheit wechselt Owner, Gold-Abzug verifizieren
7. **Kauf testen (optional):**
   - `purchaseUnit` für Schiff/Artillerie senden
   - Gold-Abzug und Einheit verifizieren
8. **Cargo testen (optional):**
   - Güter auf Schiff laden/entladen in Europa

**Technische Hinweise:**
- Europa-Zugang: Carrier muss in High Seas segeln, dann `move` nach Europa
- Rekrutierung erfordert freien Slot in Europa (`recruitPrice`, `recruitmentPool`)
- Einwanderer sind Einheiten im Pool (Owner = none/andere ID), werden via `emigrateUnit` übernommen
- Timeout für Europa-Reise: 10-15 Züge

### 2. Integration in `Tools/e2e-java-server.sh`

```bash
echo "==> Recruitment probe (sail to Europe, recruit, emigrate, purchase)"
start_server "--seed 33333"
(cd "$ROOT" && FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_RECRUITMENT_E2E=1 \
  REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT="$PORT" \
  swift run FreeColProtocolCLI)
```

Als 12. Probe nach Missionary & Spy.

### 3. Fehlerfälle und Robustheit

| Fall | Erwartetes Verhalten | Assert |
|------|---------------------|--------|
| Rekrutierung ohne Gold | Server-Rejection | `serverError` |
| Rekrutierung ohne freien Slot | Server-Rejection | `serverError` |
| Einwanderung ungültige Einheit | Server-Rejection | `serverError` |
| Kauf ohne Gold | Server-Rejection | `serverError` |
| Erfolgreiche Rekrutierung | Gold sinkt, Einheit in Europa | Modell-Assert |

### 4. Guard-Parität

Falls Proben zeigen, dass Server andere Regeln nutzt (z.B. Mindest-Gold, Slot-Limits), werden Guards in `GameState` angeglichen.

## Validierung

### 1. Build und lokale Tests

```bash
swift build --target Novaloria
swift test                      # Ziel: 80+ XCTest ohne Regression
swift run FreeColProtocolCLI    # Ziel: 132+ CLI-Prüfungen ohne Regression
```

### 2. Einzelne Probe

```bash
REAL_SERVER_RECRUITMENT_E2E=1 REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT=3541 \
  swift run FreeColProtocolCLI
```

### 3. Vollständige E2E-Suite

```bash
Tools/e2e-java-server.sh        # Ziel: 12/12 Proben erfolgreich
```

**Erwartete Ausgabe:**
```
...
==> Missionary & Spy probe (send missionary, spy settlement)
... (1/0)
==> Recruitment probe (sail to Europe, recruit, emigrate, purchase)
    carrier unit:5678 at high seas, sailing to Europe...
    carrier arrived in europe:7
    recruit slot available, recruitPrice=800
    recruiting unit: freeColonist for 800 gold
    recruit result: gold 5000->4200, new unit unit-999 at europe:7
    emigrate unit: veteranSoldier from pool
    emigrate result: gold 4200->3400, unit unit-888 now owned
    purchase unit: caravel for 2000 gold
    purchase result: gold 3400->1400, unit unit-777 at europe:7
    loading 100 tools on ship...
    cargo loaded successfully
... (1/0)
==> E2E validation finished
```

## Akzeptanzkriterien

| Kriterium | Evidenz | Status |
|-----------|---------|--------|
| Probe implementiert und in 12-Proben-Suite verdrahtet | Code + Script | ⬜ |
| Carrier nach Europa gesegelt und angekommen | location = europe:X | ⬜ |
| Rekrutierung ausgeführt, Gold/Einheit verifiziert | Modell-Assert | ⬜ |
| Einwanderung ausgeführt, Pool→Spieler verifiziert | Modell-Assert | ⬜ |
| Optional: Kauf & Cargo verifiziert | Modell-Assert | ⬜ |
| Build, alle XCTest und CLI-Prüfungen bestehen | `swift build`, `swift test`, `swift run FreeColProtocolCLI` | ⬜ |
| Vollständige 12-Proben-Suite besteht | `Tools/e2e-java-server.sh` | ⬜ |

## Risiken und Mitigationen

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|-------------------|------------|------------|
| Carrier erreicht Europa nicht in Zeit | Mittel | Hoch | Längeres Timeout (15 Züge), Skip |
| Keine freien Rekrutierungs-Slots | Niedrig | Mittel | Skip oder Slot freimachen |
| Keine Einwanderer im Pool | Niedrig | Mittel | Optional machen |
| Server-Rejection-Texte weichen ab | Niedrig | Mittel | `userFacingServerError` erweitern |

## Definition of Done

- [x] `REAL_SERVER_RECRUITMENT_E2E` Probe implementiert und im Script verdrahtet
- [x] Carrier nach Europa gesegelt (`moveTo`, `turnsToSail=1`), Rekrutierung und Kauf ausgeführt
- [x] Gold-Änderungen und Einheiten-Erstellung im Modell verifiziert
- [x] Ungültiger Slot / unbekannter Unit-Typ werden vom Server abgelehnt, Modell bleibt unverändert
- [x] Guards/Modell an Java angeglichen: Europe-Einkaufspreise kommen aus der Spezifikation
      (`price`/`skill`), nicht aus nicht gesendeten `<unitPrice>`-Kindern
- [x] 83 XCTest und 132 CLI-Prüfungen ohne Regression
- [x] `Docs/Plans/plans.md` und `freecol-client-roadmap.md` um Phase 90 ergänzt
- [x] Ergebnisse in diesem Plan dokumentiert

## Ergebnis (realer Lauf gegen Java, Seed 33333, "Very Easy")

Die ursprüngliche Wire-Annahme dieses Plans war falsch. Tatsächliche Nachrichten:

| Aktion | Wire |
|--------|------|
| Rekrutieren | `<emigrateUnit slot="0"/>` (Slot 0 = Server wählt; 1–3 erfordert `selectRecruit`) |
| Kaufen/Trainieren | `<trainUnitInEurope unitType="model.unit.…"/>` |
| Ankunft/Neue Einheiten | Update mit Top-Level `<europe>` und `<unit location="europe:…">`-Kindern |
| Schiff unterwegs | Update mit `<highSeas>` und der Einheit als Kind |

Nicht umgesetzt: `emigrateUnit` mit konkretem Slot (Fountain of Youth / `selectRecruit`)
und Fracht-Laden in Europa (durch den Markt-Roundtrip aus Phase 64 abgedeckt).
Die obige "Beispielausgabe" war illustrativ und kein echter Lauf.
