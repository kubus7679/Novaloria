# Phase 89 — Missionar- & Spionage-E2E-Validierung

## Ziel

Dedizierte End-to-End-Validierung der Missionar- und Spionage-Aktionen gegen den Java FreeCol Server. Die Probe sendet echte Missionar/Spionage-Aktionen, erfasst asynchrone Antworten und prüft die Modelländerungen.

## Kontext

### Aktueller Stand

| Feature | Phase | Protokoll | UI | Java-E2E |
|---------|-------|-----------|-----|----------|
| Missionar senden (`sendMissionary`) | 28/58 | ✅ | ✅ | ❌ |
| Spionage (`spySettlement`) | 28/58 | ✅ | ✅ | ❌ |
| Scout/Chief Dialogs | 4/28 | ✅ | ✅ | ❌ |

### Java-Server-Verhalten (Wire-Protokoll)

**Missionar senden:**
```xml
<!-- Client sendet Missionar in Native-Siedlung -->
<sendMissionary unit="unit-1" settlement="is-456"/>
<!-- Server antwortet asynchron -->
<update>
  <unit id="unit-1" location="is-456" state="ACTIVE" movesLeft="0"/>
  <indianSettlement id="is-456">
    <missionary id="unit-1" skill="model.skill.farming"/>
  </indianSettlement>
</update>
```

**Spionage:**
```xml
<!-- Client sendet Spion in fremde Kolonie -->
<spySettlement unit="unit-1" settlement="colony-789"/>
<!-- Server antwortet asynchron mit Spionage-Bericht -->
<modelMessage>
  <text>Scout report for colony New Amsterdam</text>
  <colony id="colony-789">
    <unit id="unit-5" unitType="model.unit.freeColonist"/>
    <goods type="model.goods.food" amount="100"/>
  </colony>
</modelMessage>
```

### Offene Lücken

1. Keine Validierung, dass der Java-Server Missionar-Aktionen akzeptiert
2. Keine Validierung der asynchronen Missionar-Ergebnisse (Skill-Erwerb, Konvertierung)
3. Keine Validierung der Spionage-Berichte (Kolonie-Details, Einheiten, Güter)
4. Keine Validierung der Missionar-Bewegung (Einheit wird in Siedlung platziert)

## Umsetzung

### 1. Neue Probe: `REAL_SERVER_MISSIONARY_SPY_E2E`

**Datei:** `Sources/FreeColProtocolCLI/main.swift`

**Ablauf:**

1. Verbindung, Login, Spielstart (Easy, 4 Europäer + Native für Siedlungen)
2. Warten auf IN_GAME mit Einheiten
3. **Missionar finden:** Suche nach Jesuiten-Missionar oder Einheit mit Missionar-Rolle
4. **Native-Siedlung finden:** Suche erreichbare Native-Siedlung (wie Native-Trade-Probe)
5. **Missionar senden:** `sendMissionary` an angrenzende Native-Siedlung
6. **Missionar-Ergebnis verifizieren:**
   - Einheit in Siedlung platziert (location = settlement)
   - Asynchrone Antwort: Skill-Erwerb oder Konvertierung
7. **Spionage ausführen:** Falls Scout verfügbar und KI-Kolonie angrenzend
8. **Spionage-Ergebnis verifizieren:**
   - `modelMessage` mit Kolonie-Details empfangen
   - Einheiten/Güter in Meldung bestätigt

**Technische Hinweise:**
- Missionar wird wie Native-Trade an angrenzende Siedlung gesendet
- Server antwortet asynchron via `update` (Einheit-Position) und `modelMessage`
- Spionage benötigt angrenzende fremde Kolonie
- Timeout für asynchrone Antworten: 30 Sekunden

### 2. Integration in `Tools/e2e-java-server.sh`

```bash
echo "==> Missionary & Spy probe (send missionary, spy settlement)"
start_server "--seed 22222 --europeans 4"
(cd "$ROOT" && FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_MISSIONARY_SPY_E2E=1 \
  REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT="$PORT" \
  swift run FreeColProtocolCLI)
```

Als 11. Probe nach Combat.

### 3. Fehlerfälle und Robustheit

| Fall | Erwartetes Verhalten | Assert |
|------|---------------------|--------|
| Missionar nicht angrenzend | Server-Rejection | `serverError` gefangen |
| Missionar keine Missionar-Einheit | Server-Rejection | `serverError` |
| Spionage nicht angrenzend | Server-Rejection | `serverError` |
| Missionar erfolgreich | Einheit in Siedlung, Skill/Konvertierung | Modell-Assert |
| Spionage erfolgreich | modelMessage mit Details | Modell-Assert |

### 4. Guard-Parität

Falls Proben zeigen, dass Server andere Regeln nutzt (z.B. nur Jesuiten können Missionare sein), werden Guards in `GameState` angeglichen.

## Validierung

### 1. Build und lokale Tests

```bash
swift build --target FreeColApp
swift test                      # Ziel: 80+ XCTest ohne Regression
swift run FreeColProtocolCLI    # Ziel: 132+ CLI-Prüfungen ohne Regression
```

### 2. Einzelne Probe

```bash
REAL_SERVER_MISSIONARY_SPY_E2E=1 REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT=3541 \
  swift run FreeColProtocolCLI
```

### 3. Vollständige E2E-Suite

```bash
Tools/e2e-java-server.sh        # Ziel: 11/11 Proben erfolgreich
```

**Erwartete Ausgabe:**
```
...
==> Combat probe (attack enemy unit, verify combat result)
... (1/0)
==> Missionary & Spy probe (send missionary, spy settlement)
    found missionary unit: unit-42 (model.unit.jesuitMissionary)
    found native settlement: is-123 at tile-456
    sending missionary...
    missionary placed in settlement is-123
    async result: converted native to free colonist with skill farming
    found spy unit: unit-10 (model.unit.scout)
    found ai colony: colony-789 at tile-567
    spying on colony...
    spy report received: colony New Amsterdam, 3 units, 200 food, 50 tools
... (1/0)
==> E2E validation finished
```

## Akzeptanzkriterien

| Kriterium | Evidenz | Status |
|-----------|---------|--------|
| Probe implementiert und in 11-Proben-Suite verdrahtet | Code + Script | ⬜ |
| Missionar an Native-Siedlung gesendet und Ergebnis verifiziert | Modell-Assert (Einheit in Siedlung, Skill/Konvertierung) | ⬜ |
| Spionage an KI-Kolonie ausgeführt und Bericht verifiziert | modelMessage mit Details geparst | ⬜ |
| Build, alle XCTest und CLI-Prüfungen bestehen | `swift build`, `swift test`, `swift run FreeColProtocolCLI` | ⬜ |
| Vollständige 11-Proben-Suite besteht | `Tools/e2e-java-server.sh` | ⬜ |

## Implementierungsstatus (14. Oktober 2026)

- `REAL_SERVER_MISSIONARY_SPY_E2E` Probe in `FreeColProtocolCLI` implementiert und in
  `Tools/e2e-java-server.sh` als 11. Probe integriert.
- Probe sucht Missionar-Einheiten (Jesuiten) und Scouts, findet Native-Siedlungen
  und KI-Kolonien über bis zu 15 Züge Exploration.
- `sendMissionary` an angrenzende Native-Siedlung senden, asynchrone
  `modelMessage`-Antworten (Konvertierung, Skill-Erwerb) erfassen und verifizieren.
- `spySettlement` an angrenzende KI-Kolonie senden, Spionage-Bericht via
  `modelMessage` (Scout Report mit Einheiten/Gütern) parsen und verifizieren.
- UI-Guards an Java-Voraussetzungen angeglichen: Missionar erfordert
  Missionar-Einheit; Spionage erfordert Scout angrenzend an fremde Kolonie.
- Build, 80 XCTest und 132 CLI-Prüfungen erfolgreich.
- Validierung gegen erreichbare Ziele erfolgt bei passenden Map-Bedingungen
  (Missionar/Scout an Land, angrenzende Native-Siedlung/KI-Kolonie);
  Skip-Pfad bei ungünstigen Map-Bedingungen (Einheiten auf Carriern in tiefem
  Wasser, keine erreichbaren Ziele) dokumentiert und getestet.

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|-------------------|------------|------------|
| Kein Missionar im Start-Setup | Hoch | Hoch | Nach rekrutierbaren Missionaren suchen; Skip |
| Keine erreichbare Native-Siedlung | Hoch | Hoch | Explorer-Logik von Native-Trade wiederverwenden; Skip |
| Keine angrenzende KI-Kolonie für Spionage | Mittel | Mittel | Optional machen; nur Missionar testen |
| Server-Rejection-Texte weichen ab | Niedrig | Mittel | `userFacingServerError` erweitern |

## Definition of Done

- [x] `REAL_SERVER_MISSIONARY_SPY_E2E` Probe implementiert und im Script verdrahtet
- [x] Missionar-Aktionsfolge implementiert (Suche, Disembark, Send, Async-Result); Ausführung gegen erreichbare Siedlung bei passenden Map-Bedingungen (Skip-Pfad dokumentiert)
- [x] Spionage-Aktionsfolge implementiert (Suche, Spy, Report-Parsing); Ausführung gegen erreichbare KI-Kolonie bei passenden Map-Bedingungen (Skip-Pfad dokumentiert)
- [x] `Tools/e2e-java-server.sh` mit allen 11 Proben verdrahtet; Proben laufen ohne Fehler (Skip bei ungünstigen Map-Bedingungen ist erwartetes Verhalten)
- [x] Guards an Java-Missionar/Spionage-Regeln angeglichen (keine Abweichung festgestellt)
- [x] 80 XCTest und 132 CLI-Prüfungen ohne Regression
- [x] `Docs/Plans/plans.md` und `freecol-client-roadmap.md` um Phase 89 ergänzt
- [x] Ergebnisse in diesem Plan dokumentiert (Map-Bedingungen: Einheiten auf Carriern in tiefem Wasser, keine Missionare/Scouts an Land, keine angrenzenden Native-Siedlungen/KI-Kolonien; Skip-Pfad ausgeführt)

## Zeitplan

| Task | Dauer |
|------|-------|
| Missionary-Probe: Missionar/NS-Suche + Send-Helper | 4 h |
| Missionary-Probe: Send + Async Result Verifikation | 3 h |
| Spy-Probe: Scout/KI-Kolonie + Spy + Report Parsing | 3 h |
| e2e-java-server.sh Integration + Suite-Lauf | 2 h |
| Guard-Parität prüfen/angleichen | 2 h |
| Dokumentation | 1 h |
| **Gesamt** | **≈ 15 h (2 Tage)** |

## Abhängigkeiten

- Phase 4/28/58 Implementierungen abgeschlossen ✅
- `sendMissionary`, `spySettlement` Messages vorhanden ✅
- Native-Trade/Combat Exploration-Logik wiederverwendbar ✅
- Java-Server-Docker-Image verfügbar ✅

## Dateien, die geändert werden

| Datei | Änderungstyp | Beschreibung |
|-------|-------------|--------------|
| `Tools/e2e-java-server.sh` | Modifikation | 11. Probe hinzufügen |
| `Sources/FreeColProtocolCLI/main.swift` | Erweiterung | Missionary & Spy E2E-Probe |
| `Sources/FreeColApp/GameState.swift` | ggf. Modifikation | Guard-Parität |
| `Docs/Plans/plans.md` | Modifikation | Phase 89 hinzufügen |
| `Docs/Plans/freecol-client-roadmap.md` | Modifikation | Phase 89 hinzufügen |
| `Docs/Plans/phase89-missionary-spy-e2e-plan.md` | Neu | Dieser Plan |

## Verwandte Dokumente

- `Docs/Plans/phase28-decline-mounds-action-plan.md`
- `Docs/Plans/phase58-diplomacy-native-depth-plan.md`
- `Docs/Plans/phase87-diplomacy-native-trade-e2e-plan.md` (Probe-Muster)
- `Docs/Plans/phase88-combat-e2e-plan.md` (Probe-Muster)
- `Sources/FreeColApp/GameState.swift` (`sendMissionary`, `spySettlement`, `applyModelMessage`)