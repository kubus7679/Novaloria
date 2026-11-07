# Phase 84 — Trade Route E2E Validation

## Ziel

Dedizierte End-to-End-Validierung der automatischen Handelsrouten-Ausführung (Phase 83) gegen den Java FreeCol Server. Die automatische Ausführung von Handelsrouten beim Zugende muss gegen den echten Server verifiziert werden, da die bisherige Validierung nur lokal (MockServer) und auf Protokollebene erfolgte.

## Kontext

Phase 83 implementierte `executeTradeRoutes()` in `GameState`:
- Alle zugewiesenen Routen werden beim Zugende verarbeitet
- Träger bewegen sich zum nächsten Stop
- Güter werden entladen/geladen
- Stop-Zähler wird inkrementiert
- Route loopt nach letztem Stop zum ersten

**Offen:**
- Kein dedizierter Java-E2E-Test für die automatische Ausführung
- `Tools/e2e-java-server.sh` enthält nur Smoke/Deep/Gameplay/Rejection-Proben
- Keine Validierung, dass der Server die Routenausführung korrekt verarbeitet

## Umsetzung

### 1. Erweitere `Tools/e2e-java-server.sh` um Trade-Route-Probe

**Änderung:** Füge eine 5. Probe hinzu, die speziell die automatische Routenausführung testet.

```bash
# Nach der Rejection-Probe einfügen:
echo "==> Trade Route Execution probe (automatic route execution at turn end)"
start_server
(cd "$ROOT" && FREECOL_CLI_REAL_SERVER_ONLY=1 REAL_SERVER_TRADE_ROUTE_E2E=1 \
  REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT="$PORT" \
  swift run FreeColProtocolCLI)
```

**Anforderungen an die Probe:**
- Server mit Easy-Difficulty starten (schnelleres Spiel)
- Kolonie gründen (für erste Stop)
- Handelsroute mit 2 Stops erstellen (Kolonie ↔ Europa)
- Route einem Carrier zuweisen
- `endTurn` ausführen
- Verifizieren:
  - Carrier bewegt sich in Richtung ersten Stops
  - Nach Ankunft: Güter werden entladen/geladen
  - `currentStop`-Zähler wird inkrementiert
  - Route loopt nach letztem Stop

### 2. Implementiere `REAL_SERVER_TRADE_ROUTE_E2E` in `FreeColProtocolCLI`

**Neue Datei/Erweiterung:** `Sources/FreeColProtocolCLI/TradeRouteE2EProbe.swift` oder Erweiterung von `main.swift`.

**Probe-Ablauf:**

```swift
// 1. Verbindung und Login
client.connect(to: host, port: port)
try client.login(...)  // Nutze erste verfügbare Nation

// 2. Wartet auf IN_GAME Zustand
try awaitGameState(state: .inGame)

// 3. Wähle erste Einheit (sollte Carrier sein)
let carrier = gameState.units.first { $0.isCarrier }
guard let carrier else { fatalError("No carrier found") }

// 4. Bewege Carrier zur Küste (falls nicht bereits dort)
//    - Finde eine freie Küstenkachel
//    - Nutze moveTo für direkte Bewegung

// 5. Gründe eine Kolonie mit einem Colonist
//    - Bewege Colonist an Küste
//    - buildColony mit gültigem Namen
let colony = try foundColony()

// 6. Erstelle Handelsroute mit 2 Stops
//    - Stop 1: Die gegründete Kolonie
//    - Stop 2: Europa
let route = TradeRoute(
    id: "test-route",
    name: "Test Route",
    stops: [
        TradeRouteStop(colony: colony.id, cargo: [...]),
        TradeRouteStop(europe: true, cargo: [...])
    ]
)

// 7. Weise Route dem Carrier zu
try client.assignTradeRoute(unit: carrier.id, tradeRoute: route.id)

// 8. Führe Zugende aus
try client.endTurn()

// 9. Verifiziere:
//    a) Carrier hat sich bewegt
let oldLocation = carrier.location
try awaitTurnChange()
let updatedCarrier = gameState.unit(for: carrier.id)
assert(updatedCarrier.location != oldLocation, "Carrier did not move")

//    b) Route currentStop wurde inkrementiert
let updatedRoute = gameState.tradeRoute(for: route.id)
assert(updatedRoute.currentStop == 1, "Current stop not incremented")

//    c) Güter wurden geladen/entladen (falls am Stop angekommen)
//       - Dies erfordert möglicherweise mehrere Züge
//       - Prüfe Carrier.cargo nach dem ersten Zugende

// 10. Führe weiteren Zugende aus, um Loop-Verhalten zu testen
//     - Nach letzter Stop: currentStop sollte zurück auf 0 setzen
```

**Technische Details:**
- Nutze bestehende Helper aus `GameplayE2EProbe` (Phase 63)
- Erwarte `newTurn` und `setCurrentPlayer` Nachrichten
- Verarbeite alle `update`/`partial` Nachrichten nach dem Zugende
- Nutze `GameState` für Model-Zugriff

### 3. Trade-Route-spezifische Assertions

**Zu prüfende Szenarien:**

| Szenario | Erwartetes Ergebnis | Assertion |
|----------|---------------------|-----------|
| Carrier nicht am Stop | Bewegt sich zum nächsten Stop | `carrier.location` ändert sich |
| Carrier am Stop angekommen | Güter werden entladen/geladen | `carrier.cargo` aktualisiert |
| Route mit 2 Stops | currentStop inkrementiert von 0→1 | `route.currentStop == 1` |
| Nach letztem Stop | currentStop setzt zurück auf 0 | `route.currentStop == 0` |
| Unzureichende Güter | Partial load/unload | `carrier.cargo` teilweise gefüllt |
| Volle Ladung | Kein weiteres Laden | `carrier.cargo` bleibt unverändert |

### 4. Server-Konfiguration für die Probe

**Optimale Einstellungen für schnelle Tests:**
- Difficulty: Easy (schnellere Produktion)
- Map Size: Small (schnellere Erkundung)
- Segelzeit: 1 Zug (sofortige Europa-Ankunft)

**Implementierung in `start_server()`:**
```bash
# Aktuell: Easy-Difficulty
docker run -d --name "$CONTAINER" -p "$PORT":3541 -v "$VOLUME":/data \
    "$IMAGE" --difficulty Easy >/dev/null

# Für Trade-Route-Probe: Zusätzliche Parameter
# --quickStart (falls unterstützt) oder Map-Generator-Optionen
```

### 5. Fehlerbehandlung und Robustheit

**Zu behandelnde Edge Cases:**
- Kein Carrier verfügbar → Probe überspringen mit Warnung
- Keine gültige Küstenkachel → Alternative Strategie (Europa-Start)
- Server-Ist-nicht-in-IN_GAME-Zustand → Warte und versuche erneut
- Timeout für einzelne Schritte (max. 30 Sekunden pro Operation)

**Probe-Ergebnis:**
- Erfolg: Alle Assertions passieren → Exit Code 0
- Teilweiser Erfolg: Einige Assertions passieren → Exit Code 0 mit Warnungen
- Fehler: Kritische Assertion scheitert → Exit Code 1 mit Fehlermeldung

## Validierung

### 1. Build und lokale Tests
```bash
swift build --target Novaloria
swift test  # Ziel: 80 Tests passieren
```

### 2. CLI Integration Tests
```bash
swift run FreeColProtocolCLI  # Ziel: 132+ Prüfungen passieren
```

### 3. Trade-Route-spezifische CLI Tests
```bash
# Manuell testen
REAL_SERVER_TRADE_ROUTE_E2E=1 REAL_SERVER_HOST=127.0.0.1 REAL_SERVER_PORT=3541 \
  swift run FreeColProtocolCLI
```

### 4. Vollständige E2E-Suite
```bash
Tools/e2e-java-server.sh  # Ziel: 5/5 Proben erfolgreich
```

**Erwartete Ausgabe:**
```
==> Smoke probe (connect / login / launch transport)
... (1/0)
==> Deep probe (pre-game to in-game on a fresh server)
... (1/0)
==> Gameplay probe (colony, warehouse, trade route, market, move and end turn)
... (1/0)
==> Rejection probe (illegal action produces a Java server error reply)
... (1/0)
==> Trade Route Execution probe (automatic route execution at turn end)
... (1/0)
==> E2E validation finished
```

## Akzeptanzkriterien

| Kriterium | Evidenz | Status |
|-----------|---------|--------|
| Trade-Route-Probe läuft gegen Java-Server | `Tools/e2e-java-server.sh` zeigt 5/5 | ⬜ |
| Carrier bewegt sich zu Stops | Location-Änderung nach `endTurn` | ⬜ |
| currentStop wird inkrementiert | `route.currentStop` Wert | ⬜ |
| Route loopt korrekt | currentStop → 0 nach letztem Stop | ⬜ |
| Güter werden geladen/entladen | `carrier.cargo` Änderungen | ⬜ |
| Alle bestehenden Tests passieren | 80 XCTest, 132+ CLI | ⬜ |
| Keine Regressionen | Smoke/Deep/Gameplay/Rejection Proben | ⬜ |

## Risiken und Mitigationen

| Risiko | Wahrscheinlichkeit | Auswirkung | Mitigation |
|--------|-------------------|------------|------------|
| Java-Server verhält sich anders als erwartet | Mittel | Hoch | Vorab manuelle Tests gegen Java-Server, Logs analysieren |
| Route-Ausführung dauert mehrere Züge | Hoch | Mittel | Probe über mehrere Züge ausführen, Assertions anpassen |
| Keine gültige Test-Konfiguration (Küstenkacheln) | Niedrig | Hoch | Mehrere Map-Typen testen, alternative Strategien |
| Carrier kann Route nicht zugewiesen werden | Niedrig | Hoch | Server-Fähigkeiten prüfen, Route-Validierung vor Assign |
| Timeout bei langlaufenden Proben | Mittel | Mittel | Zeitlimits pro Schritt, detaillierte Logs |
| Server-Disconnect während Probe | Niedrig | Hoch | Reconnect-Logik in CLI, Probe neu starten |

## Definition of Done

- [ ] `Tools/e2e-java-server.sh` enthält Trade-Route-Probe
- [ ] `FreeColProtocolCLI` implementiert `REAL_SERVER_TRADE_ROUTE_E2E`
- [ ] Alle Assertions für Carrier-Bewegung, Stop-Inkrement, Güter-Handling passieren
- [ ] 80 XCTest passieren
- [ ] 132+ CLI-Prüfungen passieren
- [ ] Alle 5 E2E-Proben erfolgreich (Smoke/Deep/Gameplay/Rejection/TradeRoute)
- [ ] `phase84-trade-route-e2e-validation-plan.md` dokumentiert Ergebnisse
- [ ] Code in `main` Branch gemerged

## Zeitplan

| Task | Dauer | Verantwortlich |
|------|-------|----------------|
| Design der Probe | 2 Stunden | Entwickler |
| Implementierung CLI-Erweiterung | 4 Stunden | Entwickler |
| Integration in e2e-java-server.sh | 1 Stunde | Entwickler |
| Lokale Tests | 2 Stunden | Entwickler |
| Java-Server-Validierung | 4 Stunden | Entwickler |
| Dokumentation | 1 Stunde | Entwickler |
| **Gesamt** | **14 Stunden** | **1–2 Tage** |

## Abhängigkeiten

- Phase 83 (Automated Trade Route Execution) muss abgeschlossen sein ✅
- `executeTradeRoutes()` muss in `GameState` vorhanden sein ✅
- `assignTradeRoute` Message muss implementiert sein ✅
- Java-Server-Docker-Image muss verfügbar sein

## Dateien, die geändert werden

| Datei | Änderungstyp | Beschreibung |
|-------|-------------|--------------|
| `Tools/e2e-java-server.sh` | Modifikation | 5. Probe hinzufügen |
| `Sources/FreeColProtocolCLI/main.swift` | Erweiterung | Trade-Route-E2E-Logik |
| `Docs/Plans/phase84-trade-route-e2e-validation-plan.md` | Neu | Dieser Plan |
| `Docs/Plans/plans.md` | Modifikation | Phase 84 hinzufügen |

## Verwandte Dokumente

- `Docs/Plans/phase83-automated-trade-route-execution-plan.md`
- `Docs/Plans/phase63-gameplay-e2e-plan.md` (Gameplay-Probe Referenz)
- `Docs/Plans/phase64-market-trade-e2e-plan.md` (E2E-Proben Struktur)
- `Sources/Novaloria/GameState+TradeRoutes.swift` (Implementierung)
