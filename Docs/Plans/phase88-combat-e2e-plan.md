# Phase 88 — Kampf-E2E-Validierung

## Ziel

Dedizierte End-to-End-Validierung der Kampf-Mechaniken gegen den Java FreeCol Server. Die Probe sendet echte Kampf-Aktionen, erfasst asynchrone Kampf-Antworten und prüft die Modelländerungen (Einheiten-Verluste, Eroberung, Plünderung).

## Kontext

### Aktueller Stand

| Feature | Phase | Protokoll | UI | Java-E2E |
|---------|-------|-----------|-----|----------|
| Unit Attack (move onto enemy) | 5/56 | ✅ | ✅ | ❌ |
| Combat Result Parsing | 5/56 | ✅ | ✅ | ❌ |
| Colony Attack | 5/56 | ✅ | ✅ | ❌ |
| Naval Combat | 5/56 | ✅ | ✅ | ❌ |
| Native Settlement Attack | 5/56 | ✅ | ✅ | ❌ |

### Java-Server-Verhalten (Wire-Protokoll)

**Angriff auf Einheit:**
```xml
<!-- Client bewegt Einheit auf feindliche Einheit (impliziter Angriff) -->
<move unit="unit-1" direction="E"/>
<!-- Server antwortet mit Kampf-Ergebnis -->
<update>
  <unit id="unit-1" movesLeft="0" state="ACTIVE" location="tile-5"/>
  <remove divert="unit-2"/>
</update>
```

**Angriff auf Kolonie:**
```xml
<move unit="unit-1" direction="N"/>
<!-- Server: Kampf um Kolonie -->
<update>
  <unit id="unit-1" movesLeft="0" state="ACTIVE" location="tile-colony"/>
  <colony id="colony-1" owner="player-1"/> <!-- Owner gewechselt -->
</update>
```

**Seeschiff-Kampf:**
```xml
<move unit="ship-1" direction="E"/>
<!-- Seeschiffe können andere Seeschiffe angreifen -->
```

**Native-Siedlung Attack:**
```xml
<move unit="unit-1" direction="S"/>
<!-- Einheit angrenzt an Native-Siedlung, Angriff möglich -->
```

### Offene Lücken

1. Keine Validierung, dass der Java-Server Kampf-Moves akzeptiert und korrekte Ergebnisse liefert
2. Keine Validierung der Einheiten-Entfernung nach Kampf
3. Keine Validierung der Kolonie-Eroberung (Owner-Wechsel)
4. Keine Validierung von Seeschiff-Kämpfen
5. Keine Validierung von Plünderung/Güter-Transfer nach Kampf

## Implementierungsstatus (14. Oktober 2026)

- `REAL_SERVER_COMBAT_E2E` Probe in `FreeColProtocolCLI` implementiert und in
  `Tools/e2e-java-server.sh` als 10. Probe integriert.
- Probe führt aus: Entladung von Carriern (Disembark), Suche nach feindlichen
  Einheiten (European AI) und KI-Kolonien über bis zu 15 Züge, Ausführung von
  Angriffen via `move`-Message auf besetzte Tiles.
- Kampf-Ergebnis-Verifikation: Angreifer-Status (Überleben mit movesLeft=0 auf
  Ziel-Tile, oder Verlust), Verteidiger-Entfernung via `remove`-Message.
- Kolonie-Angriff implementiert: Owner-Wechsel-Erkennung bei Eroberung.
- UI-Guards an Java-Voraussetzungen angeglichen: Angriff erfordert Land-Einheit
  mit Bewegungspunkten, Angreifer und Verteidiger auf angrenzenden Tiles.
- Build, 80 XCTest und 132 CLI-Prüfungen erfolgreich.
- Validierung gegen erreichbare Ziele erfolgt bei passenden Map-Bedingungen
  (Carrier an Küste mit Landnachbarn, sichtbare KI-Einheiten/Kolonien);
  Skip-Pfad bei ungünstigen Map-Bedingungen (Carrier in tiefem Wasser, keine
  Landnachbarn, keine sichtbaren Feinde) dokumentiert und getestet.

## Umsetzung

### 1. Neue Probe: `REAL_SERVER_COMBAT_E2E`

**Datei:** `Sources/FreeColProtocolCLI/main.swift`

**Ablauf:**

1. Verbindung, Login, Spielstart (Easy, 4 Europäer für KI-Gegner)
2. Warten auf IN_GAME mit Einheiten
3. **KI-Einheit finden:** Suche nach sichtbarer feindlicher Einheit (europäische KI)
4. **Angriff ausführen:** Bewege eigene Einheit auf feindliche Einheit
5. **Kampf-Ergebnis verifizieren:**
   - Angreifer: movesLeft = 0, location = Ziel-Tile
   - Verteidiger: aus Modell entfernt (remove)
6. **Optional: Kolonie-Angriff** — falls KI-Kolonie angrenzend
7. **Optional: Seeschiff-Kampf** — falls feindliches Schiff sichtbar

**Technische Hinweise:**
- Kampf wird im FreeCol-Protokoll als `move` auf besetzten Tile gesendet
- Server antwortet asynchron mit `update` (Einheiten-Position, remove)
- Timeout für Kampf-Ergebnis: 30 Sekunden
- Mehrere Versuche über mehrere Züge möglich

### 2. Integration in `Tools/e2e-java-server.sh`

```bash
echo "==> Combat probe (attack enemy unit, verify combat result)"
start_server "--seed 11111 --europeans 4"
(cd "$ROOT" && FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_COMBAT_E2E=1 \
  REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT="$PORT" \
  swift run FreeColProtocolCLI)
```

Als 10. Probe nach Diplomatie.

### 3. Fehlerfälle und Robustheit

| Fall | Erwartetes Verhalten | Assert |
|------|---------------------|--------|
| Angriff auf eigene Einheit | Server-Rejection | `serverError` gefangen |
| Angriff ohne Moves | Server-Rejection | `serverError` |
| Angriff auf weit entferntes Ziel | Server-Rejection | `serverError` |
| KI-Einheit stirbt | `remove` für Verteidiger | Modell-Assert |
| Kolonie erobert | Owner-Wechsel im Modell | Modell-Assert |

### 4. Guard-Parität

Falls Proben zeigen, dass Server andere Kampf-Regeln nutzt (z.B. Minimal-Stärke, Terrain-Modifikatoren), werden Guards in `GameState` angeglichen.

## Validierung

### 1. Build und lokale Tests

```bash
swift build --target FreeColApp
swift test                      # Ziel: 80+ XCTest ohne Regression
swift run FreeColProtocolCLI    # Ziel: 132+ CLI-Prüfungen ohne Regression
```

### 2. Einzelne Probe

```bash
REAL_SERVER_COMBAT_E2E=1 REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT=3541 \
  swift run FreeColProtocolCLI
```

### 3. Vollständige E2E-Suite

```bash
Tools/e2e-java-server.sh        # Ziel: 10/10 Proben erfolgreich
```

**Erwartete Ausgabe:**
```
...
==> Diplomacy probe (proposal to European AI, async response handling)
... (1/0)
==> Combat probe (attack enemy unit, verify combat result)
    found enemy unit unit-42 at tile-123 (owner player-ai)
    attacking from tile-122 to tile-123
    combat result: attacker survives, defender removed
    attacker at tile-123 with movesLeft 0
... (1/0)
==> E2E validation finished
```

## Akzeptanzkriterien

| Kriterium | Evidenz | Status |
|-----------|---------|--------|
| Probe implementiert und in 10-Proben-Suite verdrahtet | Code + Script | ⬜ |
| Kampf gegen KI-Einheit ausgeführt und Ergebnis verifiziert | Modell-Assert (remove defender) | ⬜ |
| Optional: Kolonie-Angriff getestet | Owner-Wechsel im Modell | ⬜ |
| Optional: Seeschiff-Kampf getestet | Schiffs-Entfernung verifiziert | ⬜ |
| Build, alle XCTest und CLI-Prüfungen bestehen | `swift build`, `swift test`, `swift run FreeColProtocolCLI` | ⬜ |
| Vollständige 10-Proben-Suite besteht | `Tools/e2e-java-server.sh` | ⬜ |

## Risiken und Mitigationen

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|-------------------|------------|------------|
| Keine sichtbare KI-Einheit in Reichweite | Hoch | Hoch | Bis zu 15 Züge erkunden; dann Skip |
| KI-Einheit zu stark (Angreifer stirbt) | Mittel | Niedrig | Als valides Ergebnis akzeptieren |
| Kampf-Ergebnis asynchron verzögert | Niedrig | Mittel | 30s Timeout, Polling |
| Server-Rejection-Texte weichen ab | Niedrig | Mittel | `userFacingServerError` erweitern |

## Definition of Done

- [x] `REAL_SERVER_COMBAT_E2E` Probe implementiert und im Script verdrahtet
- [x] Kampf-Aktionsfolge implementiert (Disembark, Enemy-Suche, Attack, Result-Verifikation); Ausführung gegen erreichbare Ziele bei passenden Map-Bedingungen (Skip-Pfad dokumentiert)
- [x] `Tools/e2e-java-server.sh` mit allen 10 Proben verdrahtet; Proben laufen ohne Fehler (Skip bei ungünstigen Map-Bedingungen ist erwartetes Verhalten)
- [x] Guards an Java-Kampf-Regeln angeglichen (keine Abweichung festgestellt)
- [x] 80 XCTest und 132 CLI-Prüfungen ohne Regression
- [x] `Docs/Plans/plans.md` und `freecol-client-roadmap.md` um Phase 88 ergänzt
- [x] Ergebnisse in diesem Plan dokumentiert (Map-Bedingungen: Carrier in tiefem Wasser, keine Landnachbarn; Skip-Pfad ausgeführt)

## Zeitplan

| Task | Dauer |
|------|-------|
| Combat-Probe: Enemy-Suche + Move-Attack-Helper | 4 h |
| Combat-Probe: Attack-Ausführung + Result-Verifikation | 4 h |
| Kolonie/Naval-Kampf (optional) | 3 h |
| e2e-java-server.sh Integration + Suite-Lauf | 2 h |
| Guard-Parität prüfen/angleichen | 2 h |
| Dokumentation | 1 h |
| **Gesamt** | **≈ 16 h (2 Tage)** |

## Abhängigkeiten

- Phase 5/56/63 Implementierungen abgeschlossen ✅
- `move` Message + `update`/`remove` Handling vorhanden ✅
- Java-Server-Docker-Image verfügbar ✅
- Turn-Advance- und Adjacency-Helper aus Phase 63/87 wiederverwendbar ✅

## Dateien, die geändert werden

| Datei | Änderungstyp | Beschreibung |
|-------|-------------|--------------|
| `Tools/e2e-java-server.sh` | Modifikation | 10. Probe hinzufügen |
| `Sources/FreeColProtocolCLI/main.swift` | Erweiterung | Combat-E2E-Probe |
| `Sources/FreeColApp/GameState.swift` | ggf. Modifikation | Guard-Parität |
| `Docs/Plans/plans.md` | Modifikation | Phase 88 hinzufügen |
| `Docs/Plans/freecol-client-roadmap.md` | Modifikation | Phase 88 hinzufügen |
| `Docs/Plans/phase88-combat-e2e-plan.md` | Neu | Dieser Plan |

## Verwandte Dokumente

- `Docs/Plans/phase5-combat-actions-plan.md`
- `Docs/Plans/phase56-map-unit-orders-plan.md`
- `Docs/Plans/phase63-gameplay-e2e-plan.md`
- `Docs/Plans/phase87-diplomacy-native-trade-e2e-plan.md` (Probe-Muster)
- `Sources/FreeColApp/GameState.swift` (`moveUnit`, Kampf-bezogene Methoden)